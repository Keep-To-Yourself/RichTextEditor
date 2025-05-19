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
    
    // FIXME: 光标漂移问题（同下 toggleOrderedList）
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
        var affectedParagraphRanges: [NSRange] = getAffectedParagraphRanges()
        //		if selectedNSRange.length == 0 {
        //			affectedParagraphRanges.append(
        //				fullTextNSString.paragraphRange(for: selectedNSRange)
        //			)
        //		} else {
        //			var currentPosition = selectedNSRange.location
        //			while currentPosition < NSMaxRange(selectedNSRange) {
        //				let paraRange = fullTextNSString.paragraphRange(
        //					for: NSRange(location: currentPosition, length: 0)
        //				)
        //				affectedParagraphRanges.append(paraRange)
        //				currentPosition = NSMaxRange(paraRange)
        //				if paraRange.length == 0
        //					&& currentPosition >= NSMaxRange(selectedNSRange)
        //				{
        //					break
        //				}
        //			}
        //			affectedParagraphRanges = Array(Set(affectedParagraphRanges)).sorted
        //			{ $0.location < $1.location }
        //		}
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
            return (attrs[NSAttributedString.Key.blockType] as? String) == "blockquote"
        }
        let convertToBlockquoteStyle = !allCurrentlyBlockquoted
        
        textStorageRef.beginEditing()
        
        for paraRange in affectedParagraphRanges.reversed() {  // 从后向前处理以避免范围问题
            guard paraRange.location + paraRange.length <= textStorageRef.length
            else { continue }
            // 对于末尾的空范围（通常是由于最后一个换行符被 paragraphRange 包含），如果长度为0，则跳过实际的属性设置，除非它是文档中唯一的行。
            if paraRange.length == 0
                && paraRange.location == textStorageRef.length
                && textStorageRef.length > 0 {
                continue
            }
            
            let currentAttributes = textStorageRef.attributes(
                at: paraRange.location,
                effectiveRange: nil
            )
            let currentMetadata = currentAttributes[.metadata] as? [String: Any]
            let isOriginallyListItem = currentMetadata != nil  // 必须有元数据
            && ((currentAttributes[.blockType] as? String == "list")  // 原本是纯列表项
                || (currentAttributes[.blockType] as? String == "blockquote"))  // 或者已经是被引用的列表项
            
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
                    newAttrs[.paragraphStyle] =
                    BlockquoteContent.getParagraphStyle(level: level + 1)  // 引用块内的列表缩进
                    newAttrs[.metadata] = newMetadata
                } else {
                    // 普通段落变为引用块，清除可能冲突的元数据
                    newAttrs[.paragraphStyle] =
                    BlockquoteContent.getParagraphStyle(level: 0)  // 引用块的基础缩进
                    newAttrs.removeValue(forKey: .metadata)
                }
                
                textStorageRef.addAttributes(newAttrs, range: paraRange)
                
                // 处理零宽字符 (ZWS)
                if isOriginallyListItem {  // 列表项已包含ZWS，更新其属性
                    if paraRange.length > 0 &&
                        textStorageRef.attributedSubstring(from: NSRange(location: paraRange.location, length: 1)).string == "\u{200B}" {
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
                                as? String == "blockquote" {
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
                    newAttrs[.paragraphStyle] = ListContent.getParagraphStyle(level: level - 1)  // 恢复列表项的缩进
                    newAttrs[.metadata] = newMetadata
                    // blockID 和 metadata 保留
                    textStorageRef.addAttributes(newAttrs, range: paraRange)
                    // 更新ZWS属性
                    if paraRange.length > 0
                        && textStorageRef.attributedSubstring(from: NSRange(location: paraRange.location, length: 1)).string == "\u{200B}" {
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
            let currentBlockIsList = (newTypingAttributes[NSAttributedString.Key.blockType] as? String) == "list"
            let currentListIsOrdered = (newTypingAttributes[NSAttributedString.Key.metadata] as? [String: Any])?["ordered"] as? Bool
            
            if currentBlockIsList && currentListIsOrdered == targetOrderedState {
                // 再次点击同类型列表按钮，取消列表
                newTypingAttributes[NSAttributedString.Key.blockType] = "paragraph"
                newTypingAttributes.removeValue(forKey: NSAttributedString.Key.metadata)
                newTypingAttributes.removeValue(forKey: NSAttributedString.Key.paragraphStyle)
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
                if paraRange.length == 0 && currentPosition >= NSMaxRange(selectedNSRange) {
                    break
                }
            }
            affectedParagraphRanges = Array(Set(affectedParagraphRanges)).sorted { $0.location < $1.location }
        }
        if affectedParagraphRanges.isEmpty { return }
        
        // 为本次操作中创建的新顶级列表项生成一个共享的 parentID
        let newTopLevelListParentID = UUID()
        
        textStorageRef.beginEditing()
        
        for paraRange in affectedParagraphRanges.reversed() {  // 从后向前处理以避免范围问题
            guard paraRange.location + paraRange.length <= textStorageRef.length else { continue }
            if paraRange.length == 0
                && paraRange.location == textStorageRef.length
                && textStorageRef.length > 0 {
                continue
            }
            
            let currentAttributes = textStorageRef.attributes(
                at: paraRange.location,
                effectiveRange: nil
            )
            let currentBlockType = currentAttributes[NSAttributedString.Key.blockType] as? String
            var currentMetadata = currentAttributes[NSAttributedString.Key.metadata] as? [String: Any]
            
            let isCurrentlyList = (currentBlockType == "list")
            let currentListOrderedStateIfList =
            currentMetadata?["ordered"] as? Bool
            
            if isCurrentlyList && currentListOrderedStateIfList == targetOrderedState {
                // --- 情况1: 当前是同类型列表 -> 转换为普通段落 ---
                self.removeListItem(itemRange: paraRange)  // 复用此方法
            } else if isCurrentlyList && currentListOrderedStateIfList != targetOrderedState {
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
                    if paraRange.length > 0 &&
                        textStorageRef.attributedSubstring(from: NSRange(location: paraRange.location,length: 1)).string == "\u{200B}" {
                        let zwsAttrs = textStorageRef.attributes(
                            at: paraRange.location,
                            effectiveRange: nil
                        )
                        if zwsAttrs[NSAttributedString.Key.blockType] as? String == "blockquote" {
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
                attributesToSet[NSAttributedString.Key.metadata] = newListMetadata
                attributesToSet[NSAttributedString.Key.paragraphStyle] = ListContent.getParagraphStyle(level: 0)  // 顶级列表的缩进
                attributesToSet[NSAttributedString.Key.blockID] =
                attributesToSet[NSAttributedString.Key.blockID] ?? UUID()  // 保留或生成块ID
                
                textStorageRef.setAttributes(attributesToSet, range: paraRange)
                
                // 处理引导性的零宽字符 \u{200B}
                var needsZWS = true
                // 之前如果移除了 Blockquote 的 ZWS，现在肯定需要新的 List ZWS
                // 如果 paraRange 原本就有 ZWS，检查它是否适合新的 List 状态
                if paraRange.length > 0
                    && textStorageRef.length > paraRange.location {
                    // 确保 paraRange.location 仍然有效
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
                                 as? [String: Any])?["level"] as? Int) == 0 {
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
                    let insertionLocation = paraRange.location  // ZWS 的插入位置
                    
                    //					print(
                    //						"DEBUG: Before ZWS insert - textStorage.length: \(textStorageRef.length)"
                    //					)
                    //					print("DEBUG: Before ZWS insert - paraRange: \(paraRange)")
                    //					print(
                    //						"DEBUG: Before ZWS insert - selectedRange: \(self.selectedRange)"
                    //					)
                    //					print(
                    //						"DEBUG: Before ZWS insert - attributesToSet for ZWS: \(attributesToSet)"
                    //					)
                    
                    // 记录操作前的选区，以便后续决定最终光标位置的参考
                    let originalSelectedRangeBeforeZWSInsert = self
                        .selectedRange
                    textStorageRef.insert(zws, at: paraRange.location)
                    
                    let newCursorLocation = insertionLocation + zws.length  // 光标应在 ZWS 之后
                    self.selectedRange = NSRange(
                        location: newCursorLocation,
                        length: 0
                    )  // 设置为光标，长度为0
                    
                    //					print(
                    //						"DEBUG: After ZWS insert - textStorage.length: \(textStorageRef.length)"
                    //					)
                    //					print(
                    //						"DEBUG: After ZWS insert - selectedRange (implicitly updated by insert): \(self.selectedRange)"
                    //					)
                } else if paraRange.length > 0
                            && textStorageRef.attributedSubstring(
                                from: NSRange(location: paraRange.location, length: 1)
                            ).string == "\u{200B}"
                {
                    // 如果 ZWS 已经存在并且被复用 (needsZWS is false)
                    // 同样确保光标在 ZWS 之后
                    let existingZWSLocation = paraRange.location
                    let newCursorLocation = existingZWSLocation + 1  // ZWS 长度为1
                    self.selectedRange = NSRange(
                        location: newCursorLocation,
                        length: 0
                    )
                    print(
                        "DEBUG: Reused ZWS - selectedRange (explicitly set): \(self.selectedRange)"
                    )
                }
            }
        }
        textStorageRef.endEditing()
        
        print("DEBUG: After endEditing - selectedRange: \(self.selectedRange)")
        
        // 5. 更新UI和状态
        self.updateListStyle()
        self.updateBlockquoteStyle()  // 如果列表和引用块有交互，也刷新它
        
        // 使用当前（已被修正的）selectedRange.location 来更新 typingAttributes
        self.updateTypingAttributesAndToolbar(at: self.selectedRange.location)
        
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
    
    // FIXME: 初始化内容应用这个捕获不准字体大小（同下decreaseIndent），自己编辑的文字没问题
    public func increaseIndent() {
        let affectedRanges = getAffectedParagraphRanges()
        // 当前实现只处理第一个受影响的段落，如果需要处理多个，需要遍历 affectedRanges
        guard let range = affectedRanges.first,
              range.location != NSNotFound,
              range.location <= self.textStorage.length
        else { return }
        
        let safeRange = NSRange(
            location: range.location,
            length: min(range.length, self.textStorage.length - range.location)
        )
        if safeRange.length < 0 { return }
        
        // 1. 获取当前段落的完整属性
        let currentAttributes = self.textStorage.attributes(
            at: safeRange.location,
            effectiveRange: nil
        )
        guard let blockType = currentAttributes[.blockType] as? String else {
            return
        }
        
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
                ],
                                               range: safeRange
                )
            }
        case "paragraph", "heading":
            let currentParaStyle =
            currentAttributes[.paragraphStyle] as? NSParagraphStyle
            let newParaStyle =
            (currentParaStyle?.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
            
            let currentIndent = newParaStyle.headIndent
            // 确保 paragraphTabWidth > 0 避免除零错误
            let currentTabs =
            paragraphTabWidth > 0 ? (currentIndent / paragraphTabWidth) : 0
            
            if currentTabs < Double(maxParagraphTabs) {
                newParaStyle.headIndent += paragraphTabWidth
                newParaStyle.firstLineHeadIndent += paragraphTabWidth
                
                // 只修改 .paragraphStyle 属性，其他属性通过 newAttributesToApply 保持不变
                self.textStorage.addAttributes([
                    .paragraphStyle: newParaStyle
                ],
                                               range: safeRange
                )
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
        guard let range = affectedRanges.first,
              range.location != NSNotFound,
              range.location <= self.textStorage.length
        else { return }
        
        let safeRange = NSRange(
            location: range.location,
            length: min(range.length, self.textStorage.length - range.location)
        )
        if safeRange.length < 0 { return }
        
        let currentAttributes = self.textStorage.attributes(
            at: safeRange.location,
            effectiveRange: nil
        )
        guard let blockType = currentAttributes[.blockType] as? String else {
            return
        }
        
        self.textStorage.beginEditing()
        var newAttributesToApply = currentAttributes  // << 关键：从当前属性开始
        
        switch blockType {
        case "list":
            var currentMetadata =
            currentAttributes[.metadata] as? [String: Any] ?? [:]
            let currentLevel = currentMetadata["level"] as? Int ?? 0
            
            if currentLevel > 0 {
                let newLevel = currentLevel - 1
                currentMetadata["level"] = newLevel
                
                newAttributesToApply[.metadata] = currentMetadata
                newAttributesToApply[.paragraphStyle] =
                ListContent.getParagraphStyle(level: newLevel)
                self.textStorage.setAttributes(
                    newAttributesToApply,
                    range: safeRange
                )
            } else {  // currentLevel is 0, 转换为段落
                var paragraphAttributes: [NSAttributedString.Key: Any] = [
                    .blockType: "paragraph",
                    .blockID: currentAttributes[.blockID] ?? UUID(),
                    // 保留原有的 .font, .foregroundColor 等内联样式
                    .font: currentAttributes[.font]
                    ?? UIFont.systemFont(
                        ofSize: editor.configuration.fontSize
                    ),
                    .foregroundColor: currentAttributes[.foregroundColor]
                    ?? editor.configuration.textColor,
                ]
                // 移除列表特有的 .metadata 和 .paragraphStyle (缩进)
                // newAttributesToApply 已经包含了这些，所以我们直接用 paragraphAttributes
                
                // ZWS 处理 (如果原始列表项有ZWS，需要移除)
                var rangeForAttributes = safeRange
                if safeRange.length > 0
                    && self.textStorage.attributedSubstring(
                        from: NSRange(location: safeRange.location, length: 1)
                    ).string == "\u{200B}"
                {
                    self.textStorage.replaceCharacters(
                        in: NSRange(location: safeRange.location, length: 1),
                        with: ""
                    )
                    
                    var textActuallyChanged = false
                    if safeRange.length > 0
                        && self.textStorage.attributedSubstring(
                            from: NSRange(
                                location: safeRange.location,
                                length: 1
                            )
                        ).string == "\u{200B}"
                    {
                        self.textStorage.replaceCharacters(
                            in: NSRange(
                                location: safeRange.location,
                                length: 1
                            ),
                            with: ""
                        )
                        textActuallyChanged = true
                    }
                    
                    newAttributesToApply.removeValue(forKey: .metadata)
                    newAttributesToApply.removeValue(forKey: .paragraphStyle)  // 移除列表的缩进样式
                    newAttributesToApply[.blockType] = "paragraph"
                    // newAttributesToApply 中的 .font, .foregroundColor 等已经从 currentAttributes 继承了。
                    self.textStorage.setAttributes(
                        newAttributesToApply,
                        range: safeRange
                    )  // 应用到原始范围，ZWS (如果之后被覆盖) 会获得新属性
                    
                } else {
                    // 如果没有ZWS，或者不是从列表转来，也确保是段落属性
                    newAttributesToApply.removeValue(forKey: .metadata)
                    newAttributesToApply.removeValue(forKey: .paragraphStyle)
                    newAttributesToApply[.blockType] = "paragraph"
                    self.textStorage.setAttributes(
                        newAttributesToApply,
                        range: safeRange
                    )
                }
            }
        case "paragraph", "heading":
            if let currentParaStyle = currentAttributes[.paragraphStyle] as? NSParagraphStyle, currentParaStyle.headIndent > 0 {
                let newParaStyle = (currentParaStyle.mutableCopy() as! NSMutableParagraphStyle)
                newParaStyle.headIndent = max(0, newParaStyle.headIndent - paragraphTabWidth)
                newParaStyle.firstLineHeadIndent = max(0, newParaStyle.firstLineHeadIndent - paragraphTabWidth)
                
                if newParaStyle.headIndent == 0 && newParaStyle.firstLineHeadIndent == 0 {
                    // 如果缩进完全移除
                    newAttributesToApply.removeValue(forKey: .paragraphStyle)
                } else {
                    newAttributesToApply[.paragraphStyle] = newParaStyle
                }
                self.textStorage.setAttributes(
                    newAttributesToApply,
                    range: safeRange
                )
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
            self.textStorage.removeAttribute(
                .paragraphStyle,
                range: safeInitialRange
            )
            
            self.textStorage.addAttributes(
                newBlockAttributes,
                range: safeInitialRange
            )
            
            var currentRange = safeInitialRange
            if (originalBlockType == "list"
                || originalBlockType == "blockquote") && currentRange.length > 0
                && self.textStorage.attributedSubstring(
                    from: NSRange(location: currentRange.location, length: 1)
                ).string == "\u{200B}"
            {
                self.textStorage.replaceCharacters(
                    in: NSRange(location: currentRange.location, length: 1),
                    with: ""
                )
            }
            
            let rangeForFontUpdate = safeInitialRange
            
            self.textStorage.enumerateAttribute(
                .font,
                in: rangeForFontUpdate,
                options: []
            ) { (value, subRange, _) in
                if NSMaxRange(subRange) > self.textStorage.length
                    || subRange.location >= self.textStorage.length {
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
                    newFont = UIFont(
                        descriptor: baseDescriptor,
                        size: defaultFontSize
                    )
                } else {
                    if symbolicTraits.isEmpty {
                        newFont = UIFont.systemFont(ofSize: defaultFontSize)
                    } else {
                        newFont = UIFont(
                            descriptor: existingFont.fontDescriptor
                                .withSymbolicTraits(symbolicTraits)
                            ?? UIFont.systemFont(ofSize: defaultFontSize)
                                .fontDescriptor,
                            size: defaultFontSize
                        )
                    }
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
}
