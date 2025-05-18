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
        toggleAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue
        )
    }
    
    public func toggleStrikethrough() {
        toggleAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue
        )
    }
    
    /// Helper function to toggle NSAttributedString attributes like underline or strikethrough.
    private func toggleAttribute(
        _ attributeKey: NSAttributedString.Key,
        value: Any
    ) {
        // Update typing attributes for new text
        if (self.typingAttributes[attributeKey] as? NSNumber)?.isEqual(
            to: value as! NSNumber
        ) ?? false {
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
            if (currentAttribute as? NSNumber)?.isEqual(to: value as! NSNumber)
                ?? false
            {
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
        let selectedNSRange = self.selectedRange
        let textStorageRef = self.textStorage
        let fullTextNSString = textStorageRef.string as NSString
        
        // 1. 处理编辑器完全为空的特殊情况
        if textStorageRef.length == 0 {
            var newTypingAttributes = self.typingAttributes
            let currentIsBlockquote =
            (newTypingAttributes[NSAttributedString.Key.blockType]
             as? String) == "blockquote"
            if currentIsBlockquote {
                newTypingAttributes[NSAttributedString.Key.blockType] =
                "paragraph"
                newTypingAttributes.removeValue(
                    forKey: NSAttributedString.Key.paragraphStyle
                )
            } else {
                newTypingAttributes[NSAttributedString.Key.blockType] =
                "blockquote"
                newTypingAttributes[NSAttributedString.Key.paragraphStyle] =
                BlockquoteContent.getParagraphStyle(level: 0)
            }
            newTypingAttributes.removeValue(
                forKey: NSAttributedString.Key.metadata
            )
            self.typingAttributes = newTypingAttributes
            Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
            return
        }
        
        // 2. 确定受影响的段落范围
        var affectedParagraphRanges: [NSRange] = []
        if selectedNSRange.length == 0 {
            affectedParagraphRanges.append(
                fullTextNSString.paragraphRange(for: selectedNSRange)
            )
        } else {
            var currentPosition = selectedNSRange.location
            while currentPosition < NSMaxRange(selectedNSRange) {
                let paraRange = fullTextNSString.paragraphRange(
                    for: NSRange(location: currentPosition, length: 0)
                )
                affectedParagraphRanges.append(paraRange)
                currentPosition = NSMaxRange(paraRange)
                if paraRange.length == 0
                    && currentPosition >= NSMaxRange(selectedNSRange)
                {
                    break
                }
            }
            affectedParagraphRanges = Array(Set(affectedParagraphRanges)).sorted { $0.location < $1.location }
        }
        if affectedParagraphRanges.isEmpty { return }
        
        // 3. 确定全局操作：是添加还是移除引用块样式
        //    检查是否所有受影响的段落当前都已经是某种形式的引用块
        let allCurrentlyBlockquoted = affectedParagraphRanges.allSatisfy {
            paraRange in
            // 确保查询位置有效
            let queryLocation = min(
                paraRange.location,
                textStorageRef.length > 0 ? textStorageRef.length - 1 : 0
            )
            if queryLocation < 0 && textStorageRef.length == 0 { return false }  // 对完全空文本特殊处理
            guard queryLocation >= 0 else { return true }  // 若 queryLocation 无效（例如 range.location > length），则视作无需改变
            
            let attrs = textStorageRef.attributes(
                at: queryLocation,
                effectiveRange: nil
            )
            return (attrs[NSAttributedString.Key.blockType] as? String)
            == "blockquote"
        }
        let convertToBlockquoteStyle = !allCurrentlyBlockquoted
        
        textStorageRef.beginEditing()
        
        for paraRange in affectedParagraphRanges.reversed() {  // 从后向前处理以避免范围问题
            guard paraRange.location + paraRange.length <= textStorageRef.length
            else { continue }
            // 对于末尾的空范围（通常是由于最后一个换行符被 paragraphRange 包含），如果长度为0，则跳过实际的属性设置，除非它是文档中唯一的行。
            if paraRange.length == 0
                && paraRange.location == textStorageRef.length
                && textStorageRef.length > 0
            {
                continue
            }
            
            let currentAttributes = textStorageRef.attributes(
                at: paraRange.location,
                effectiveRange: nil
            )
            let currentMetadata = currentAttributes[.metadata]
            as? [String: Any]
            let isOriginallyListItem = currentMetadata != nil && // 必须有元数据
            ((currentAttributes[.blockType] as? String == "list") || // 原本是纯列表项
             (currentAttributes[.blockType] as? String == "blockquote"))  // 或者已经是被引用的列表项
            
            if convertToBlockquoteStyle {
                // --- 转换为引用块样式 ---
                var newAttrs: [NSAttributedString.Key: Any] = [:]
                newAttrs[.blockType] = "blockquote"
                newAttrs[.blockID] = currentAttributes[.blockID] ?? UUID()  // 保留或生成新的块ID
                
                if isOriginallyListItem {
                    // 元数据被保留 (因为 newAttrs 是从 currentAttributes 开始的)
                    // 列表项的 ZWS 也应该保留，只需更新其属性
                    var newMetadata = currentMetadata!
                    newMetadata["level"] = newMetadata["level"] as! Int + 1
                    let level = currentMetadata?["level"] as? Int ?? 0
                    newAttrs[.paragraphStyle] = BlockquoteContent.getParagraphStyle(level: level + 1)  // 引用块内的列表缩进
                    newAttrs[.metadata] = newMetadata
                } else {
                    // 普通段落变为引用块，清除可能冲突的元数据
                    newAttrs[.paragraphStyle] = BlockquoteContent.getParagraphStyle(level: 0)  // 引用块的基础缩进
                    newAttrs.removeValue(forKey: .metadata)
                }
                
                textStorageRef.addAttributes(newAttrs, range: paraRange)
                
                // 处理零宽字符 (ZWS)
                if isOriginallyListItem {  // 列表项已包含ZWS，更新其属性
                    if paraRange.length > 0
                        && textStorageRef.attributedSubstring(
                            from: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        ).string == "\u{200B}"
                    {
                        textStorageRef.addAttributes(
                            newAttrs,
                            range: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        )
                    } else if paraRange.length >= 0 {  // 如果列表项为空或没有ZWS (不规范)，则插入
                        let zws = NSAttributedString(
                            string: "\u{200B}",
                            attributes: newAttrs
                        )
                        textStorageRef.insert(zws, at: paraRange.location)
                    }
                } else {  // 普通段落变为引用块，需要添加ZWS
                    var needsZWS = true
                    if paraRange.length > 0 {
                        let firstChar = textStorageRef.attributedSubstring(
                            from: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        )
                        if firstChar.string == "\u{200B}" {
                            let zwsAttrs = firstChar.attributes(
                                at: 0,
                                effectiveRange: nil
                            )
                            if zwsAttrs[NSAttributedString.Key.blockType]
                                as? String == "blockquote"
                            {
                                needsZWS = false  // 已有合适的引用块ZWS
                            } else {  // ZWS存在但类型不对，移除它，稍后添加新的
                                textStorageRef.replaceCharacters(
                                    in: NSRange(
                                        location: paraRange.location,
                                        length: 1
                                    ),
                                    with: ""
                                )
                            }
                        }
                    }
                    if needsZWS {
                        let zws = NSAttributedString(
                            string: "\u{200B}",
                            attributes: newAttrs
                        )
                        textStorageRef.insert(zws, at: paraRange.location)
                    }
                }
                
            } else {
                // --- 移除引用块样式 ---
                if isOriginallyListItem {  // 原本是“被引用的列表项”，现在变回“普通列表项”
                    var newAttrs: [NSAttributedString.Key: Any] = [:]
                    newAttrs[NSAttributedString.Key.blockType] = "list"  // 恢复 blockType 为 list
                    
                    var newMetadata = currentMetadata!
                    newMetadata["level"] = newMetadata["level"] as! Int - 1
                    let level = currentMetadata?["level"] as! Int
                    newAttrs[.paragraphStyle] = ListContent.getParagraphStyle(level: level - 1) // 恢复列表项的缩进
                    newAttrs[.metadata] = newMetadata
                    // blockID 和 metadata 保留
                    textStorageRef.addAttributes(newAttrs, range: paraRange)
                    // 更新ZWS属性
                    if paraRange.length > 0
                        && textStorageRef.attributedSubstring(
                            from: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        ).string == "\u{200B}"
                    {
                        textStorageRef.addAttributes(
                            newAttrs,
                            range: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        )
                    }
                } else {  // 原本是“纯文本的引用块行”
                    self.removeBlockquote(lineRange: paraRange)  // 使用现有方法转换为普通段落
                }
            }
        }
        textStorageRef.endEditing()
        
        // 5. 更新UI和状态
        self.updateBlockquoteStyle()
        self.updateListStyle()
        
        let finalCursorPos = min(
            selectedNSRange.location,
            textStorageRef.length
        )
        var finalTypingAttributes: [NSAttributedString.Key: Any]
        if textStorageRef.length == 0 {
            let defaultFontSize = self.editor.configuration.fontSize
            finalTypingAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(
                    ofSize: defaultFontSize
                ),
                NSAttributedString.Key.foregroundColor: UIColor.label,
                NSAttributedString.Key.blockType: "paragraph",
            ]
        } else if finalCursorPos == textStorageRef.length {
            finalTypingAttributes = textStorageRef.attributes(
                at: max(0, finalCursorPos - 1),
                effectiveRange: nil
            )
        } else {
            finalTypingAttributes = textStorageRef.attributes(
                at: finalCursorPos,
                effectiveRange: nil
            )
        }
        self.typingAttributes = finalTypingAttributes
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
    
    public func toggleOrderedList() {
        self.toggleList(targetOrderedState: true)
    }
    
    public func toggleUnorderedList() {
        self.toggleList(targetOrderedState: false)
    }
    
    private func toggleList(targetOrderedState: Bool) {
        let selectedNSRange = self.selectedRange
        let textStorageRef = self.textStorage
        let fullTextNSString = textStorageRef.string as NSString
        
        // 1. 处理编辑器完全为空的特殊情况
        if textStorageRef.length == 0 {
            var newTypingAttributes = self.typingAttributes
            let currentBlockIsList =
            (newTypingAttributes[NSAttributedString.Key.blockType]
             as? String) == "list"
            let currentListIsOrdered =
            (newTypingAttributes[NSAttributedString.Key.metadata]
             as? [String: Any])?["ordered"] as? Bool
            
            if currentBlockIsList && currentListIsOrdered == targetOrderedState
            {  // 再次点击同类型列表按钮，取消列表
                newTypingAttributes[NSAttributedString.Key.blockType] =
                "paragraph"
                newTypingAttributes.removeValue(
                    forKey: NSAttributedString.Key.metadata
                )
                newTypingAttributes.removeValue(
                    forKey: NSAttributedString.Key.paragraphStyle
                )
            } else {  // 应用列表或切换列表类型
                newTypingAttributes[NSAttributedString.Key.blockType] = "list"
                let listMetadata: [String: Any] = [
                    "level": 0,  // 顶级列表
                    "ordered": targetOrderedState,
                    "id": UUID(),
                    "parentID": UUID(),  // 新列表的父ID
                ]
                newTypingAttributes[NSAttributedString.Key.metadata] =
                listMetadata
                newTypingAttributes[NSAttributedString.Key.paragraphStyle] =
                ListContent.getParagraphStyle(level: 0)
            }
            self.typingAttributes = newTypingAttributes
            Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
            return
        }
        
        // 2. 确定受影响的段落范围
        var affectedParagraphRanges: [NSRange] = []
        if selectedNSRange.length == 0 {
            affectedParagraphRanges.append(
                fullTextNSString.paragraphRange(for: selectedNSRange)
            )
        } else {
            var currentPosition = selectedNSRange.location
            while currentPosition < NSMaxRange(selectedNSRange) {
                let paraRange = fullTextNSString.paragraphRange(
                    for: NSRange(location: currentPosition, length: 0)
                )
                affectedParagraphRanges.append(paraRange)
                currentPosition = NSMaxRange(paraRange)
                if paraRange.length == 0
                    && currentPosition >= NSMaxRange(selectedNSRange)
                {
                    break
                }
            }
            affectedParagraphRanges = Array(Set(affectedParagraphRanges)).sorted
            { $0.location < $1.location }
        }
        if affectedParagraphRanges.isEmpty { return }
        
        // 为本次操作中创建的新顶级列表项生成一个共享的 parentID
        let newTopLevelListParentID = UUID()
        
        textStorageRef.beginEditing()
        
        for paraRange in affectedParagraphRanges.reversed() {  // 从后向前处理以避免范围问题
            guard paraRange.location + paraRange.length <= textStorageRef.length
            else { continue }
            if paraRange.length == 0
                && paraRange.location == textStorageRef.length
                && textStorageRef.length > 0
            {
                continue
            }
            
            let currentAttributes = textStorageRef.attributes(
                at: paraRange.location,
                effectiveRange: nil
            )
            let currentBlockType =
            currentAttributes[NSAttributedString.Key.blockType] as? String
            var currentMetadata =
            currentAttributes[NSAttributedString.Key.metadata]
            as? [String: Any]
            
            let isCurrentlyList = (currentBlockType == "list")
            let currentListOrderedStateIfList =
            currentMetadata?["ordered"] as? Bool
            
            if isCurrentlyList
                && currentListOrderedStateIfList == targetOrderedState
            {
                // --- 情况1: 当前是同类型列表 -> 转换为普通段落 ---
                self.removeListItem(itemRange: paraRange)  // 复用此方法
            } else if isCurrentlyList
                        && currentListOrderedStateIfList != targetOrderedState
            {
                // --- 情况2: 当前是不同类型列表 -> 切换列表类型 ---
                if var meta = currentMetadata {
                    meta["ordered"] = targetOrderedState
                    // meta["id"] = UUID() // 通常保留项ID，只改变类型
                    textStorageRef.addAttribute(
                        NSAttributedString.Key.metadata,
                        value: meta,
                        range: paraRange
                    )
                    // 更新零宽字符的属性
                    if paraRange.length > 0
                        && textStorageRef.attributedSubstring(
                            from: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        ).string == "\u{200B}"
                    {
                        var zwsAttrs = textStorageRef.attributes(
                            at: paraRange.location,
                            effectiveRange: nil
                        )
                        zwsAttrs[NSAttributedString.Key.metadata] = meta  // 确保ZWS的metadata也更新
                        textStorageRef.setAttributes(
                            zwsAttrs,
                            range: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        )
                    }
                }
            } else {
                // --- 情况3: 当前不是列表 (是段落、引用块等) -> 转换为新列表项 ---
                var attributesToSet = currentAttributes  // 保留内联样式
                
                // 如果当前是引用块，先移除引用块的特定样式 (段落样式会被列表样式覆盖)
                if currentBlockType == "blockquote" {
                    // ZWS 如果是引用块的，需要特殊处理
                    if paraRange.length > 0
                        && textStorageRef.attributedSubstring(
                            from: NSRange(
                                location: paraRange.location,
                                length: 1
                            )
                        ).string == "\u{200B}"
                    {
                        let zwsAttrs = textStorageRef.attributes(
                            at: paraRange.location,
                            effectiveRange: nil
                        )
                        if zwsAttrs[NSAttributedString.Key.blockType] as? String
                            == "blockquote"
                        {
                            textStorageRef.replaceCharacters(
                                in: NSRange(
                                    location: paraRange.location,
                                    length: 1
                                ),
                                with: ""
                            )
                            // 注意：paraRange 的长度和后续操作基于的文本已改变，后续对 paraRange 的使用需要小心
                            // 更好的做法是记录需要移除ZWS，在设置新属性后统一处理或调整paraRange
                            // 为简化，这里先移除。如果paraRange只包含ZWS，移除后paraRange长度会变0。
                            // 然而，由于我们是从后向前处理，对当前paraRange的修改不影响之前已处理的。
                            // 但插入新的ZWS时，位置仍是paraRange.location。
                        }
                    }
                }
                
                attributesToSet[NSAttributedString.Key.blockType] = "list"
                let newListMetadata: [String: Any] = [
                    "level": 0,  // 新列表项默认为顶级
                    "ordered": targetOrderedState,
                    "id": UUID(),  // 每个列表项有唯一ID
                    "parentID": newTopLevelListParentID,  // 同一批次转换的顶级列表项共享此父ID
                ]
                attributesToSet[NSAttributedString.Key.metadata] =
                newListMetadata
                attributesToSet[NSAttributedString.Key.paragraphStyle] =
                ListContent.getParagraphStyle(level: 0)  // 顶级列表的缩进
                attributesToSet[NSAttributedString.Key.blockID] =
                attributesToSet[NSAttributedString.Key.blockID] ?? UUID()  // 保留或生成块ID
                
                textStorageRef.setAttributes(attributesToSet, range: paraRange)
                
                // 处理引导性的零宽字符 \u{200B}
                var needsZWS = true
                // 之前如果移除了 Blockquote 的 ZWS，现在肯定需要新的 List ZWS
                // 如果 paraRange 原本就有 ZWS，检查它是否适合新的 List 状态
                if paraRange.length > 0
                    && textStorageRef.length > paraRange.location
                {  // 确保 paraRange.location 仍然有效
                    let firstChar = textStorageRef.attributedSubstring(
                        from: NSRange(location: paraRange.location, length: 1)
                    )
                    if firstChar.string == "\u{200B}" {
                        let zwsAttrs = firstChar.attributes(
                            at: 0,
                            effectiveRange: nil
                        )
                        if zwsAttrs[NSAttributedString.Key.blockType] as? String
                            == "list"
                            && ((zwsAttrs[NSAttributedString.Key.metadata]
                                 as? [String: Any])?["ordered"] as? Bool)
                            == targetOrderedState
                            && ((zwsAttrs[NSAttributedString.Key.metadata]
                                 as? [String: Any])?["level"] as? Int) == 0
                        {
                            needsZWS = false  // 已存在合适的ZWS
                        } else {  // ZWS存在但类型不对，移除它
                            textStorageRef.replaceCharacters(
                                in: NSRange(
                                    location: paraRange.location,
                                    length: 1
                                ),
                                with: ""
                            )
                        }
                    }
                }
                if needsZWS {
                    let zws = NSAttributedString(
                        string: "\u{200B}",
                        attributes: attributesToSet
                    )  // ZWS获取列表项的完整属性
                    textStorageRef.insert(zws, at: paraRange.location)
                }
            }
        }
        textStorageRef.endEditing()
        
        // 5. 更新UI和状态
        self.updateListStyle()
        self.updateBlockquoteStyle()  // 如果列表和引用块有交互，也刷新它
        
        let finalCursorPos = min(
            selectedNSRange.location,
            textStorageRef.length
        )
        var finalTypingAttributes: [NSAttributedString.Key: Any]
        if textStorageRef.length == 0 {
            let defaultFontSize = self.editor.configuration.fontSize
            finalTypingAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(
                    ofSize: defaultFontSize
                ),
                NSAttributedString.Key.foregroundColor: UIColor.label,
                NSAttributedString.Key.blockType: "paragraph",
            ]
        } else if finalCursorPos == textStorageRef.length {
            finalTypingAttributes = textStorageRef.attributes(
                at: max(0, finalCursorPos - 1),
                effectiveRange: nil
            )
        } else {
            finalTypingAttributes = textStorageRef.attributes(
                at: finalCursorPos,
                effectiveRange: nil
            )
        }
        self.typingAttributes = finalTypingAttributes
        Toolbar.shared.updateButtonStates(basedOn: self.typingAttributes)
    }
}
