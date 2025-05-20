//
//  File.swift
//  RichTextEditor
//
//  Created by 易汉斌 on 2025/5/18.
//

import UIKit

// MARK: - UIFont Styling Extensions
// These helpers make working with font traits cleaner.
// They were previously in Toolbar.swift; centralizing them here or in a global utility is good.
extension UIFont {
    /// Returns a new font with the specified symbolic traits added to the existing ones.
    func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let combinedTraits = fontDescriptor.symbolicTraits.union(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(combinedTraits)
        else {
            return self  // Fallback to self if descriptor fails
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    /// Returns a new font with the specified symbolic traits removed from the existing ones.
    func withoutTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let remainingTraits = fontDescriptor.symbolicTraits.subtracting(traits)
        guard
            let descriptor = fontDescriptor.withSymbolicTraits(remainingTraits)
        else {
            return self  // Fallback to self if descriptor fails
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    /// Checks if the font has the bold trait.
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    /// Checks if the font has the italic trait.
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
}

// MARK: - TextEditor Styling Extension
extension TextEditor {
    
    private var maxListLevel: Int { 3 }
    private var listIndentWidth: CGFloat { 24.0 }
    private var paragraphTabWidth: CGFloat { 24.0 }
    private var maxParagraphTabs: Int { 3 }
    
    // MARK: - Font Trait Styling (Bold, Italic)
    
    public func toggleBold() {
        applyFontTraitTransformation { currentFont in
            return currentFont.isBold
            ? currentFont.withoutTraits(traits: .traitBold)
            : currentFont.withTraits(traits: .traitBold)
        }
    }
    
    public func toggleItalic() {
        applyFontTraitTransformation { currentFont in
            return currentFont.isItalic
            ? currentFont.withoutTraits(traits: .traitItalic)
            : currentFont.withTraits(traits: .traitItalic)
        }
    }
    
    /// Helper function to apply font trait transformations to typing attributes and current selection.
    /// - Parameter transform: A closure that takes the current font and returns the new font.
    private func applyFontTraitTransformation(transform: (UIFont) -> UIFont) {
        // --- 1. Handle Typing Attributes (for new text if no selection, or for the cursor's style) ---
        let currentTypingFont = self.typingAttributes[.font] as? UIFont
        // Use the font size from typingAttributes, or fallback to the editor's configured default font size
        let fontSizeForTypingAttributes =
        currentTypingFont?.pointSize ?? self.editor.configuration.fontSize
        let baseFontForTypingAttributes =
        currentTypingFont
        ?? UIFont.systemFont(ofSize: fontSizeForTypingAttributes)
        
        // Apply the transformation (e.g., add/remove bold) to the font determined for typing attributes
        let newFontForTypingAttributes = transform(baseFontForTypingAttributes)
        self.typingAttributes[.font] = newFontForTypingAttributes  // Update for future typing
        
        // --- 2. Handle Selected Text (if any) ---
        if selectedRange.length > 0 {
            let rangeToStyle = selectedRange
            
            // Group attribute changes for better performance and undo management
            self.textStorage.beginEditing()
            
            // Enumerate through the selected range. For each segment with a distinct font,
            // apply the transformation while preserving its original size and other non-conflicting traits.
            self.textStorage.enumerateAttribute(
                .font,
                in: rangeToStyle,
                options: []
            ) { (value, subRange, stop) in
                // Get the font for the current segment within the selection.
                // If a segment unexpectedly has no font, default to a system font with the editor's configured default size.
                let fontInSelectionSegment =
                value as? UIFont
                ?? UIFont.systemFont(
                    ofSize: self.editor.configuration.fontSize
                )
                
                // Apply the desired transformation (e.g., bold/italic toggle) to this specific font segment.
                // This 'transform' closure comes from toggleBold() or toggleItalic() and knows how to add/remove the specific trait.
                let transformedFontForSelectionSegment = transform(
                    fontInSelectionSegment
                )
                
                // Apply the newly transformed font back to this specific sub-range of the text storage.
                self.textStorage.addAttribute(
                    .font,
                    value: transformedFontForSelectionSegment,
                    range: subRange
                )
            }
            self.textStorage.endEditing()
        }
        
        // --- 3. Refresh Toolbar Button States ---
        // The toolbar should reflect the current state of typingAttributes.
        // If a selection was modified, textViewDidChangeSelection will also likely fire
        // and update typingAttributes based on the new cursor position/selection state.
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    // MARK: - Decoration Styling (Underline, Strikethrough)
    
    public func toggleUnderline() {
        toggleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
    }
    
    public func toggleStrikethrough() {
        toggleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
    }
    
    /// Helper function to toggle NSAttributedString attributes like underline or strikethrough.
    private func toggleAttribute(_ attributeKey: NSAttributedString.Key, value: Any) {
        // Update typing attributes for new text
        if (self.typingAttributes[attributeKey] as? NSNumber)?.isEqual(to: value as! NSNumber) ?? false {
            self.typingAttributes.removeValue(forKey: attributeKey)
        } else {
            self.typingAttributes[attributeKey] = value
        }
        
        // Apply to the currently selected text, if any
        if selectedRange.length > 0 {
            let currentAttribute = self.textStorage.attribute(
                attributeKey,
                at: selectedRange.location,
                effectiveRange: nil
            )
            if (currentAttribute as? NSNumber)?.isEqual(to: value as! NSNumber) ?? false {
                self.textStorage.removeAttribute(
                    attributeKey,
                    range: selectedRange
                )
            } else {
                self.textStorage.addAttribute(
                    attributeKey,
                    value: value,
                    range: selectedRange
                )
            }
        }
        
        // Refresh the toolbar to reflect the new state
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    public func toggleBlockquote() {
        let fullText = self.textStorage.string as NSString
        
        if self.textStorage.length == 0 {
            // 编辑器完全为空
            self.toBlockquote(lineRange: NSRange(location: 0, length: 0))
            return
        }
        
        var start = self.selectedRange.lowerBound
        var end = self.selectedRange.upperBound
        
        if start == end {
            let lineRange = fullText.lineRange(for: NSRange(location: start, length: 0))
            let line = self.textStorage.attributedSubstring(from: lineRange)
            
            let blockType = line.attribute(.blockType, at: 0, effectiveRange: nil) as! String
            switch blockType {
            case "paragraph":
                self.toBlockquote(lineRange: lineRange)
                // move cursor
                self.selectedRange = NSRange(location: start + 1, length: 0)
            case "list":
                let metadata = line.attribute(.metadata, at: 0, effectiveRange: nil) as! [String: Any]
                let ordered = metadata["ordered"] as! Bool
                self.removeListItem(itemRange: lineRange)
                self.toBlockquote(lineRange: NSRange(location: lineRange.location, length: lineRange.length - 1))
                self.toBlockquoteListItem(itemRange: lineRange, ordered: ordered)
            case "blockquote":
                // 处理引用块的列表项
                let metadata = line.attribute(.metadata, at: 0, effectiveRange: nil) as? [String: Any]
                if metadata == nil {
                    self.removeBlockquote(lineRange: lineRange)
                    // move cursor
                    self.selectedRange = NSRange(location: start - 1, length: 0)
                } else {
                    let ordered = metadata!["ordered"] as! Bool
                    self.removeListItemInBlockquote(itemRange: lineRange)
                    self.removeBlockquote(lineRange: lineRange)
                    self.toListItem(itemRange: NSRange(location: lineRange.location, length: lineRange.length - 1), ordered: ordered)
                }
            default:
                break
            }
        } else {
            var cursor = self.selectedRange
            while start < end {
                let lineRange = fullText.lineRange(for: NSRange(location: start, length: 0))
                let line = self.textStorage.attributedSubstring(from: lineRange)
                
                let blockType = line.attribute(.blockType, at: 0, effectiveRange: nil) as! String
                switch blockType {
                case "paragraph":
                    self.toBlockquote(lineRange: lineRange)
                    start = lineRange.upperBound + 1
                    end = end + 1
                    if cursor.location >= lineRange.location && cursor.location < lineRange.upperBound {
                        cursor.location = cursor.location + 1
                    }
                    if cursor.location <= lineRange.location && cursor.location + cursor.length >= lineRange.location {
                        cursor.length = cursor.length + 1
                    }
                case "list":
                    let metadata = line.attribute(.metadata, at: 0, effectiveRange: nil) as! [String: Any]
                    let ordered = metadata["ordered"] as! Bool
                    self.removeListItem(itemRange: lineRange)
                    self.toBlockquote(lineRange: NSRange(location: lineRange.location, length: lineRange.length - 1))
                    self.toBlockquoteListItem(itemRange: lineRange, ordered: ordered)
                    start = lineRange.upperBound - 1
                    end = end - 1
                    if cursor.location >= lineRange.location && cursor.location < lineRange.upperBound {
                        cursor.location = cursor.location - 1
                    }
                    if cursor.location <= lineRange.location && cursor.location + cursor.length >= lineRange.location {
                        cursor.length = cursor.length - 1
                    }
                case "blockquote":
                    // 处理引用块的列表项
                    let metadata = line.attribute(.metadata, at: 0, effectiveRange: nil) as? [String: Any]
                    if metadata == nil {
                        self.removeBlockquote(lineRange: lineRange)
                        start = lineRange.upperBound - 1
                        end = end - 1
                        if cursor.location >= lineRange.location && cursor.location < lineRange.upperBound {
                            cursor.location = cursor.location - 1
                        }
                        if cursor.location <= lineRange.location && cursor.location + cursor.length >= lineRange.location {
                            cursor.length = cursor.length - 1
                        }
                    } else {
                        let ordered = metadata!["ordered"] as! Bool
                        self.removeListItemInBlockquote(itemRange: lineRange)
                        self.removeBlockquote(lineRange: lineRange)
                        self.toListItem(itemRange: NSRange(location: lineRange.location, length: lineRange.length - 1), ordered: ordered)
                        start = lineRange.upperBound
                    }
                default:
                    start = lineRange.upperBound
                }
            }
            self.selectedRange = cursor
        }
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    public func toggleOrderedList() {
        self.toggleList(targetOrderedState: true)
    }
    
    public func toggleUnorderedList() {
        self.toggleList(targetOrderedState: false)
    }
    
    private func toggleList(targetOrderedState: Bool) {
        let fullText = self.textStorage.string as NSString
        
        if self.textStorage.length == 0 {
            // 编辑器完全为空
            self.toListItem(itemRange: NSRange(location: 0, length: 0), ordered: targetOrderedState)
            return
        }
        
        var start = self.selectedRange.lowerBound
        var end = self.selectedRange.upperBound
        
        if start == end {
            let lineRange = fullText.lineRange(for: NSRange(location: start, length: 0))
            let line = self.textStorage.attributedSubstring(from: lineRange)
            
            let blockType = line.attribute(.blockType, at: 0, effectiveRange: nil) as! String
            switch blockType {
            case "paragraph":
                self.toListItem(itemRange: lineRange, ordered: targetOrderedState)
                // move cursor
                self.selectedRange = NSRange(location: start + 1, length: 0)
            case "list":
                self.removeListItem(itemRange: lineRange)
                // move cursor
                self.selectedRange = NSRange(location: start - 1, length: 0)
            case "blockquote":
                // 处理引用块的列表项
                let metadata = line.attribute(.metadata, at: 0, effectiveRange: nil) as? [String: Any]
                if metadata == nil {
                    self.toBlockquoteListItem(itemRange: lineRange, ordered: targetOrderedState)
                    // move cursor
                    self.selectedRange = NSRange(location: start, length: 0)
                } else {
                    self.removeListItemInBlockquote(itemRange: lineRange)
                    // move cursor
                    self.selectedRange = NSRange(location: start, length: 0)
                }
            default:
                break
            }
        } else {
            var cursor = self.selectedRange
            while start < end {
                let lineRange = fullText.lineRange(for: NSRange(location: start, length: 0))
                let line = self.textStorage.attributedSubstring(from: lineRange)
                
                let blockType = line.attribute(.blockType, at: 0, effectiveRange: nil) as! String
                switch blockType {
                case "paragraph":
                    self.toListItem(itemRange: lineRange, ordered: targetOrderedState)
                    start = lineRange.upperBound + 1
                    end = end + 1
                    if cursor.location >= lineRange.location && cursor.location < lineRange.upperBound {
                        cursor.location = cursor.location + 1
                    }
                    if cursor.location <= lineRange.location && cursor.location + cursor.length >= lineRange.location {
                        cursor.length = cursor.length + 1
                    }
                case "list":
                    self.removeListItem(itemRange: lineRange)
                    start = lineRange.upperBound - 1
                    end = end - 1
                    if cursor.location >= lineRange.location && cursor.location < lineRange.upperBound {
                        cursor.location = cursor.location - 1
                    }
                    if cursor.location <= lineRange.location && cursor.location + cursor.length >= lineRange.location {
                        cursor.length = cursor.length - 1
                    }
                case "blockquote":
                    // 处理引用块的列表项
                    let metadata = line.attribute(.metadata, at: 0, effectiveRange: nil) as? [String: Any]
                    if metadata == nil {
                        self.toBlockquoteListItem(itemRange: lineRange, ordered: targetOrderedState)
                        start = lineRange.upperBound
                    } else {
                        self.removeListItemInBlockquote(itemRange: lineRange)
                        start = lineRange.upperBound
                    }
                default:
                    start = lineRange.upperBound
                }
            }
            self.selectedRange = cursor
        }
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    internal func getAffectedParagraphRanges() -> [NSRange] {
        let textStorageRef = self.textStorage
        guard let fullTextNSString = textStorageRef.string as NSString? else {
            return [NSRange(location: 0, length: 0)]
        }
        let currentSelectedRange = self.selectedRange
        
        var affectedParagraphRanges: [NSRange] = []
        
        if textStorageRef.length == 0 {
            affectedParagraphRanges.append(NSRange(location: 0, length: 0))
            return affectedParagraphRanges
        }
        
        if currentSelectedRange.length == 0 {
            let queryLocation = min(
                currentSelectedRange.location,
                textStorageRef.length
            )
            var paragraphRangeToQuery = NSRange(
                location: queryLocation,
                length: 0
            )
            
            if queryLocation == textStorageRef.length && queryLocation > 0 {
                paragraphRangeToQuery.location = queryLocation - 1
            }
            
            if paragraphRangeToQuery.location < 0 {
                paragraphRangeToQuery.location = 0
            }
            
            affectedParagraphRanges.append(
                fullTextNSString.paragraphRange(for: paragraphRangeToQuery)
            )
            
        } else {
            var currentPosition = currentSelectedRange.location
            let selectionEndPosition = NSMaxRange(currentSelectedRange)
            
            while currentPosition < selectionEndPosition {
                let paraRange = fullTextNSString.paragraphRange(
                    for: NSRange(location: currentPosition, length: 0)
                )
                
                if paraRange.location == NSNotFound {
                    break
                }
                
                if NSMaxRange(paraRange) > textStorageRef.length {
                    affectedParagraphRanges.append(
                        NSRange(
                            location: paraRange.location,
                            length: textStorageRef.length - paraRange.location
                        )
                    )
                    break
                }
                
                affectedParagraphRanges.append(paraRange)
                
                let nextPositionWillBe = NSMaxRange(paraRange)
                
                if nextPositionWillBe > currentPosition {
                    currentPosition = nextPositionWillBe
                } else {
                    currentPosition += 1
                }
            }
            
            if !affectedParagraphRanges.isEmpty {
                var uniqueRanges = Set<NSRange>()
                affectedParagraphRanges.forEach { uniqueRanges.insert($0) }
                affectedParagraphRanges = Array(uniqueRanges).sorted {
                    $0.location < $1.location
                }
            }
        }
        
        return affectedParagraphRanges.filter {
            $0.location != NSNotFound && $0.length >= 0
        }
    }
    
    internal func updateTypingAttributesAndToolbar(at location: Int) {
        var newTypingAttributes: [NSAttributedString.Key: Any]
        let safeLocation = min(max(0, location), self.textStorage.length)
        
        if self.textStorage.length == 0 {
            // 编辑器为空，设置默认的段落 typingAttributes
            let defaultFontSize = self.editor.configuration.fontSize
            newTypingAttributes = [
                .font: UIFont.systemFont(ofSize: defaultFontSize),
                .foregroundColor: self.editor.configuration.textColor,
                .blockType: "paragraph",
                .blockID: UUID(),
            ]
        } else if safeLocation == self.textStorage.length {
            newTypingAttributes = self.textStorage.attributes(
                at: max(0, safeLocation - 1),
                effectiveRange: nil
            )
        } else {
            newTypingAttributes = self.textStorage.attributes(
                at: safeLocation,
                effectiveRange: nil
            )
        }
        
        self.typingAttributes = newTypingAttributes
        
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    public func increaseIndent() {
        let affectedRanges = getAffectedParagraphRanges()
        // 当前实现只处理第一个受影响的段落，如果需要处理多个，需要遍历 affectedRanges
        guard let range = affectedRanges.first, range.location != NSNotFound, range.location <= self.textStorage.length else { return }
        
        let safeRange = NSRange(location: range.location,length: min(range.length, self.textStorage.length - range.location))
        if safeRange.length < 0 { return }
        
        // 1. 获取当前段落的完整属性
        let currentAttributes = self.textStorage.attributes(at: safeRange.location, effectiveRange: nil)
        let blockType = currentAttributes[.blockType] as! String
        
        self.textStorage.beginEditing()
        
        switch blockType {
        case "list":
            var currentMetadata = currentAttributes[.metadata] as? [String: Any] ?? [:]
            let currentLevel = currentMetadata["level"] as? Int ?? 0
            
            if currentLevel < maxListLevel {
                let newLevel = currentLevel + 1
                currentMetadata["level"] = newLevel
                
                // 使用 setAttributes，因为它基于 currentAttributes 构建，所以其他属性被保留
                self.textStorage.addAttributes([
                    .metadata: currentMetadata,
                    .paragraphStyle: ListContent.getParagraphStyle(level: newLevel)
                ], range: safeRange)
            }
        default:
            self.textStorage.endEditing()  // 如果没有做任何修改，也需要 endEditing
            return
        }
        
        self.textStorage.endEditing()
        self.updateTypingAttributesAndToolbar(at: safeRange.location)  // 或者更精确的光标位置
    }
    
    public func decreaseIndent() {
        let affectedRanges = getAffectedParagraphRanges()
        guard let range = affectedRanges.first, range.location != NSNotFound, range.location <= self.textStorage.length else { return }
        
        let safeRange = NSRange(location: range.location, length: min(range.length, self.textStorage.length - range.location))
        if safeRange.length < 0 { return }
        
        let currentAttributes = self.textStorage.attributes(at: safeRange.location,effectiveRange: nil)
        let blockType = currentAttributes[.blockType] as! String
        
        self.textStorage.beginEditing()
        
        switch blockType {
        case "list":
            var currentMetadata = currentAttributes[.metadata] as! [String: Any]
            let currentLevel = currentMetadata["level"] as! Int
            
            if currentLevel > 0 {
                let newLevel = currentLevel - 1
                currentMetadata["level"] = newLevel
                self.textStorage.addAttributes([
                    .metadata: currentMetadata,
                    .paragraphStyle: ListContent.getParagraphStyle(level: newLevel)
                ], range: safeRange)
            } else {
                // currentLevel is 0, 转换为段落
                // 移除列表特有的 .metadata 和 .paragraphStyle (缩进)
                
                // remove the zero-width character
                self.textStorage.replaceCharacters(in: NSRange(location: safeRange.location, length: 1), with: "")
                
                self.textStorage.addAttributes([
                    .blockType: "paragraph",
                    .blockID: UUID()
                ], range: safeRange)
                self.textStorage.removeAttribute(.metadata, range: safeRange)
                self.textStorage.removeAttribute(.paragraphStyle, range: safeRange)
            }
        default:
            self.textStorage.endEditing()
            return
        }
        
        self.textStorage.endEditing()
        
        var locationForUpdate = safeRange.location
        if blockType == "list" && (currentAttributes[.metadata] as? [String: Any])?["level"] as? Int == 0 {
            locationForUpdate = self.selectedRange.location
        }
        self.updateTypingAttributesAndToolbar(at: locationForUpdate)
    }
    
    private func headingFontSize(for level: Int, defaultSize: CGFloat) -> CGFloat {
        switch level {
        case 1: return 32
        case 2: return 24
        case 3: return 18.72
        case 4: return 16
        case 5: return 13.28
        case 6: return 10.72
        default: return 16
        }
    }
    
    public func applyHeading(level: Int) {
        let affectedRanges = getAffectedParagraphRanges()
        guard !affectedRanges.isEmpty else {
            if self.textStorage.length == 0 {
                var newTypingAttributes = self.typingAttributes
                newTypingAttributes[.blockType] = "heading"
                newTypingAttributes[.metadata] = ["level": level]
                newTypingAttributes[.blockID] =
                newTypingAttributes[.blockID] ?? UUID()
                newTypingAttributes.removeValue(forKey: .paragraphStyle)
                
                let fontSize = headingFontSize(
                    for: level,
                    defaultSize: self.editor.configuration.fontSize
                )
                var font = UIFont.systemFont(ofSize: fontSize)
                if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                    font = UIFont(descriptor: descriptor, size: fontSize)
                } else {
                    font = UIFont.boldSystemFont(ofSize: fontSize)
                }
                newTypingAttributes[.font] = font
                
                self.typingAttributes = newTypingAttributes
                Toolbar.shared.updateButtonStates(
                    basedOn: self.typingAttributes
                )
            }
            return
        }
        
        let defaultEditorFontSize = self.editor.configuration.fontSize
        let newHeadingFontSize = headingFontSize(
            for: level,
            defaultSize: defaultEditorFontSize
        )
        
        self.textStorage.beginEditing()
        
        for range in affectedRanges.reversed() {
            guard range.location != NSNotFound, range.location <= self.textStorage.length else { continue }
            let safeInitialRange = NSRange(
                location: range.location,
                length: min(
                    range.length,
                    self.textStorage.length - range.location
                )
            )
            if safeInitialRange.length < 0 { continue }
            
            let originalAttributes = self.textStorage.attributes(
                at: safeInitialRange.location,
                effectiveRange: nil
            )
            let originalBlockType = originalAttributes[.blockType] as? String
            
            var newBlockAttributes: [NSAttributedString.Key: Any] = [
                .blockType: "heading",
                .metadata: ["level": level] as [String: Any],
                .blockID: originalAttributes[.blockID] ?? UUID(),
            ]
            
            self.textStorage.removeAttribute(
                .paragraphStyle,
                range: safeInitialRange
            )
            
            var currentRange = safeInitialRange
            if (originalBlockType == "list" || originalBlockType == "blockquote") && currentRange.length > 0
                && self.textStorage.attributedSubstring(from: NSRange(location: currentRange.location, length: 1)).string == "\u{200B}" {
                self.textStorage.replaceCharacters(
                    in: NSRange(location: currentRange.location, length: 1),
                    with: ""
                )
            }
            
            self.textStorage.addAttributes(
                newBlockAttributes,
                range: currentRange
            )
            
            let rangeForFontUpdate = currentRange
            
            self.textStorage.enumerateAttribute(
                .font,
                in: rangeForFontUpdate,
                options: []
            ) { (value, subRange, _) in
                let existingFont =
                value as? UIFont
                ?? UIFont.systemFont(ofSize: newHeadingFontSize)
                var newFont: UIFont
                
                var symbolicTraits = existingFont.fontDescriptor.symbolicTraits
                symbolicTraits.insert(.traitBold)
                
                if let baseDescriptor = UIFont.systemFont(ofSize: newHeadingFontSize).fontDescriptor.withSymbolicTraits(symbolicTraits) {
                    newFont = UIFont(
                        descriptor: baseDescriptor,
                        size: newHeadingFontSize
                    )
                } else {
                    newFont = UIFont.boldSystemFont(ofSize: newHeadingFontSize)
                }
                self.textStorage.addAttribute(
                    .font,
                    value: newFont,
                    range: subRange
                )
            }
        }
        
        self.textStorage.endEditing()
        
        let locationForUpdate =
        affectedRanges.first?.location ?? self.selectedRange.location
        self.updateTypingAttributesAndToolbar(at: locationForUpdate)
    }
    
    public func applyParagraph() {
        let affectedRanges = getAffectedParagraphRanges()
        guard !affectedRanges.isEmpty else {
            if self.textStorage.length == 0 {
                var newTypingAttributes = self.typingAttributes
                newTypingAttributes[.blockType] = "paragraph"
                newTypingAttributes[.blockID] =
                newTypingAttributes[.blockID] ?? UUID()
                newTypingAttributes.removeValue(forKey: .metadata)
                newTypingAttributes.removeValue(forKey: .paragraphStyle)
                let defaultFontSize = self.editor.configuration.fontSize
                newTypingAttributes[.font] = UIFont.systemFont(ofSize: defaultFontSize)
                self.typingAttributes = newTypingAttributes
                Toolbar.shared.updateButtonStates(
                    basedOn: self.typingAttributes
                )
            }
            return
        }
        
        let defaultFontSize = self.editor.configuration.fontSize
        
        self.textStorage.beginEditing()
        
        for range in affectedRanges.reversed() {
            guard range.location != NSNotFound, range.location <= self.textStorage.length else { continue }
            let safeInitialRange = NSRange(
                location: range.location,
                length: min(
                    range.length,
                    self.textStorage.length - range.location
                )
            )
            if safeInitialRange.length < 0 { continue }
            
            let originalAttributes = self.textStorage.attributes(
                at: safeInitialRange.location,
                effectiveRange: nil
            )
            let originalBlockType = originalAttributes[.blockType] as? String
            
            var newBlockAttributes: [NSAttributedString.Key: Any] = [
                .blockType: "paragraph",
                .blockID: originalAttributes[.blockID] ?? UUID(),
            ]
            
            self.textStorage.removeAttribute(.metadata, range: safeInitialRange)
            self.textStorage.removeAttribute(.paragraphStyle, range: safeInitialRange)
            
            self.textStorage.addAttributes(newBlockAttributes, range: safeInitialRange)
            
            var currentRange = safeInitialRange
            if (originalBlockType == "list" || originalBlockType == "blockquote") && currentRange.length > 0 && self.textStorage.attributedSubstring(from: NSRange(location: currentRange.location, length: 1)).string == "\u{200B}" {
                self.textStorage.replaceCharacters(in: NSRange(location: currentRange.location, length: 1),with: "")
            }
            
            let rangeForFontUpdate = safeInitialRange
            
            self.textStorage.enumerateAttribute(.font, in: rangeForFontUpdate,options: []) { value, subRange, _ in
                if NSMaxRange(subRange) > self.textStorage.length || subRange.location >= self.textStorage.length {
                    return
                }
                if subRange.length == 0 && !(subRange.location == self.textStorage.length && self.textStorage.length == 0) {
                    return
                }
                
                let existingFont = value as? UIFont ?? UIFont.systemFont(ofSize: defaultFontSize)
                var newFont: UIFont
                
                var symbolicTraits = existingFont.fontDescriptor.symbolicTraits
                
                if originalBlockType == "heading" {
                    symbolicTraits.remove(.traitBold)
                }
                
                if let baseDescriptor = UIFont.systemFont(ofSize: defaultFontSize).fontDescriptor.withSymbolicTraits(symbolicTraits) {
                    newFont = UIFont(descriptor: baseDescriptor,size: defaultFontSize)
                } else {
                    if symbolicTraits.isEmpty {
                        newFont = UIFont.systemFont(ofSize: defaultFontSize)
                    } else {
                        newFont = UIFont(descriptor: existingFont.fontDescriptor.withSymbolicTraits(symbolicTraits) ?? UIFont.systemFont(ofSize: defaultFontSize).fontDescriptor, size: defaultFontSize)
                    }
                }
                self.textStorage.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        self.textStorage.endEditing()
        let locationForUpdate = affectedRanges.first?.location ?? self.selectedRange.location
        self.updateTypingAttributesAndToolbar(at: locationForUpdate)
    }
}
