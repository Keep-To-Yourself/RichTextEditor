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
            self.textStorage.enumerateAttribute(.font, in: rangeToStyle, options: []) { (value, subRange, stop) in
                // Get the font for the current segment within the selection.
                // If a segment unexpectedly has no font, default to a system font with the editor's configured default size.
                let fontInSelectionSegment = value as? UIFont ?? UIFont.systemFont(ofSize: self.editor.configuration.fontSize)
                
                // Apply the desired transformation (e.g., bold/italic toggle) to this specific font segment.
                // This 'transform' closure comes from toggleBold() or toggleItalic() and knows how to add/remove the specific trait.
                let transformedFontForSelectionSegment = transform(fontInSelectionSegment)
                
                // Apply the newly transformed font back to this specific sub-range of the text storage.
                self.textStorage.addAttribute(.font, value: transformedFontForSelectionSegment, range: subRange)
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
            let currentAttribute = self.textStorage.attribute(attributeKey, at: selectedRange.location, effectiveRange: nil)
            if (currentAttribute as? NSNumber)?.isEqual(to: value as! NSNumber) ?? false {
                self.textStorage.removeAttribute(attributeKey,range: selectedRange)
            } else {
                self.textStorage.addAttribute(attributeKey, value: value, range: selectedRange)
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
            if lineRange.length == 0 {
                self.toBlockquote(lineRange: lineRange)
                self.selectedRange = NSRange(location: start + 1, length: 0)
                Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
                return
            }
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
            if lineRange.length == 0 {
                self.toListItem(itemRange: lineRange, ordered: targetOrderedState)
                // move cursor
                self.selectedRange = NSRange(location: start + 1, length: 0)
                Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
                return
            }
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
    
    public func increaseIndent() {
        if self.selectedRange.length != 0 {
            return
        }
        let fullText = self.textStorage.string as NSString
        let lineRange = fullText.lineRange(for: NSRange(location: self.selectedRange.location, length: 0))
        let attributes = self.textStorage.attributes(at: lineRange.location, effectiveRange: nil)
        
        let blockType = attributes[.blockType] as! String
        
        switch blockType {
        case "list":
            var metadata = attributes[.metadata] as! [String: Any]
            let level = metadata["level"] as! Int
            let parentID = metadata["parentID"] as! UUID
            let ordered = metadata["ordered"] as! Bool
            
            if level + 1 < maxListLevel {
                let newContent = ListContent(document: self.document, parentID: parentID, items: [], ordered: ordered)
                let newLevel = level + 1
                var newMetadata = metadata
                newMetadata["level"] = newLevel
                newMetadata["parentID"] = newContent.id
                
                self.textStorage.addAttributes([
                    .metadata: newMetadata,
                    .paragraphStyle: ListContent.getParagraphStyle(level: newLevel)
                ], range: lineRange)
            }
        case "blockquote":
            guard let metadata = attributes[.metadata] as? [String: Any] else { return }
            let level = metadata["level"] as! Int
            let parentID = metadata["parentID"] as! UUID
            let ordered = metadata["ordered"] as! Bool
            
            if level + 1 < maxListLevel {
                let newContent = BlockquoteContent(document: self.document, parentID: parentID, items: [], ordered: ordered)
                let newLevel = level + 1
                var newMetadata = metadata
                newMetadata["level"] = newLevel
                newMetadata["parentID"] = newContent.id
                
                self.textStorage.addAttributes([
                    .metadata: newMetadata,
                    .paragraphStyle: BlockquoteContent.getParagraphStyle(level: newLevel)
                ], range: lineRange)
            }
        default:
            break
        }
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    public func decreaseIndent() {
        if self.selectedRange.length != 0 {
            return
        }
        let fullText = self.textStorage.string as NSString
        let lineRange = fullText.lineRange(for: NSRange(location: self.selectedRange.location, length: 0))
        let attributes = self.textStorage.attributes(at: lineRange.location, effectiveRange: nil)
        
        let blockType = attributes[.blockType] as! String
        
        switch blockType {
        case "list":
            var metadata = attributes[.metadata] as! [String: Any]
            let level = metadata["level"] as! Int
            
            if level > 0 {
                let parentID = metadata["parentID"] as! UUID
                let content = self.document.getList(parentID)!
                
                let newLevel = level - 1
                var newMetadata = metadata
                newMetadata["level"] = newLevel
                newMetadata["parentID"] = content.parentID
                
                self.textStorage.addAttributes([
                    .metadata: newMetadata,
                    .paragraphStyle: ListContent.getParagraphStyle(level: newLevel)
                ], range: lineRange)
            }
        case "blockquote":
            guard let metadata = attributes[.metadata] as? [String: Any] else { return }
            let level = metadata["level"] as! Int
            
            if level > 1 {
                let parentID = metadata["parentID"] as! UUID
                let content = self.document.getList(parentID)!
                
                let newLevel = level - 1
                var newMetadata = metadata
                newMetadata["level"] = newLevel
                newMetadata["parentID"] = content.parentID
                
                self.textStorage.addAttributes([
                    .metadata: newMetadata,
                    .paragraphStyle: BlockquoteContent.getParagraphStyle(level: newLevel)
                ], range: lineRange)
            }
        default:
            break
        }
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    public func applyHeading(level: Int) {
        if self.selectedRange.length != 0 {
            return
        }
        let fullText = self.textStorage.string as NSString
        let lineRange = fullText.lineRange(for: NSRange(location: self.selectedRange.location, length: 0))
        let attributes = self.textStorage.attributes(at: lineRange.location, effectiveRange: nil)
        
        let blockType = attributes[.blockType] as! String
        
        switch blockType {
        case "paragraph":
            self.toHeading(level: level, lineRange: lineRange)
        default:
            break
        }
    }
    
    public func applyParagraph() {
    }
}
