//
//  TextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

class TextEditor: UITextView, UITextViewDelegate {
    
    internal let editor: RichTextEditor
    internal let document: Document
    
    init(_ editor: RichTextEditor, document: Document) {
        self.editor = editor
        self.document = document
        
        super.init(frame: .zero, textContainer: nil)
        
        self.textStorage.setAttributedString(document.toAttributedString())
        self.autocapitalizationType = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            Toolbar.shared.attach(to: editor)
        }
        return result
    }
    
    override public func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            Toolbar.shared.detach()
        }
        return result
    }
    
    private func rectForTextRange(range: NSRange) -> CGRect? {
        let glyphRange = self.layoutManager.glyphRange(
            forCharacterRange: range,
            actualCharacterRange: nil
        )
        let rect = self.layoutManager.boundingRect(
            forGlyphRange: glyphRange,
            in: self.textContainer
        )
        return CGRect(
            x: rect.origin.x + textContainerInset.left,
            y: rect.origin.y + textContainerInset.top,
            width: rect.width,
            height: rect.height
        )
    }
    
    private func rectForLine(range: NSRange) -> CGRect? {
        let glyphRange = self.layoutManager.glyphRange(
            forCharacterRange: range,
            actualCharacterRange: nil
        )
        let rect = self.layoutManager.lineFragmentRect(
            forGlyphAt: glyphRange.location,
            effectiveRange: nil
        )
        return CGRect(
            x: rect.origin.x + textContainerInset.left,
            y: rect.origin.y + textContainerInset.top,
            width: rect.width,
            height: rect.height
        )
    }
    
    // 标记需要更新布局
    override var text: String! {
        didSet {
            updateBlockquoteStyle()
            updateListStyle()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateBlockquoteStyle()
        updateListStyle()
    }
    
    private var blockquoteLayers: [CALayer] = []
    
    internal func updateBlockquoteStyle() {
        // 删除所有旧图层
        blockquoteLayers.forEach { $0.removeFromSuperlayer() }
        blockquoteLayers.removeAll()
        
        // 获取所有 blockquote 范围
        let attributedText = self.textStorage
        
        var ranges = [NSRange]()
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(
            .blockType,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard value as? String == "blockquote" else { return }
            ranges.append(range)
        }
        
        // 为每个段落添加装饰
        for range in ranges {
            // 获取文本范围
            let rect = rectForTextRange(range: range)
            guard let rect = rect else { continue }
            
            // 创建装饰图层
            var layers: [CAShapeLayer] = []
            
            let fullLineMinX = textContainerInset.left + 3
            let fullLineMaxX = bounds.width - textContainerInset.right - 3
            let fullLineWidth = fullLineMaxX - fullLineMinX
            
            let padding: CGFloat = 2
            let y = rect.minY + padding
            let height = rect.height - padding * 2
            
            // 背景矩形
            let fullLineRect = CGRect(x: fullLineMinX + 6,
                                      y: y,
                                      width: fullLineWidth,
                                      height: height)
            let backgroundLayer = CAShapeLayer()
            let backgroundPath = UIBezierPath(rect: fullLineRect)
            backgroundLayer.path = backgroundPath.cgPath
            backgroundLayer.fillColor = UIColor.systemGray6
                .withAlphaComponent(0.8).cgColor
            layers.append(backgroundLayer)
            
            // 竖线
            let lineLayer = CAShapeLayer()
            let lineRect = CGRect(
                x: fullLineMinX,
                y: y,
                width: 6,
                height: height
            )
            let linePath = UIBezierPath(rect: lineRect)
            lineLayer.path = linePath.cgPath
            lineLayer.fillColor = UIColor.systemGray2.cgColor
            layers.append(lineLayer)
            
            // 添加到视图
            for layer in layers {
                self.layer.insertSublayer(layer, at: 0)
                
                blockquoteLayers.append(layer)
            }
            
            var index: [UUID: [Int: Int]] = [:]
            
            attributedText.enumerateAttribute(
                .metadata,
                in: range,
                options: []
            ) {
                value,
                range,
                _ in
                let rect = rectForLine(range: range)
                guard let rect = rect else { return }
                
                guard let value = value as? [String: Any] else { return }
                guard let level = value["level"] as? Int else { return }
                guard let ordered = value["ordered"] as? Bool else { return }
                guard let parentID = value["parentID"] as? UUID else { return }
                
                if ordered {
                    var subIndex = index[parentID] ?? [:]
                    if subIndex[level] == nil {
                        subIndex[level] = 0
                    } else {
                        subIndex[level]! += 1
                    }
                    index[parentID] = subIndex
                }
                
                let style = ordered ? getOrderedListStyle(level: level - 1, index: index[parentID]![level]!) : getUnorderedListStyle(
                    level: level - 1
                )
                
                let levelOffset = CGFloat(level) * 24
                
                let label = UILabel()
                label.text = style
                label.font = UIFont.systemFont(ofSize: 16)
                label.sizeToFit()
                let renderer = UIGraphicsImageRenderer(size: label.bounds.size)
                let image = renderer.image { ctx in
                    label.layer.render(in: ctx.cgContext)
                }
                let attachment = CALayer()
                attachment.contents = image.cgImage
                attachment.frame = CGRect(
                    x: textContainerInset.left + 8 + levelOffset,
                    y: rect.midY - label.bounds.height / 2,
                    width: label.bounds.width,
                    height: label.bounds.height
                )
                
                self.layer.insertSublayer(attachment, at: 2)
                
                blockquoteLayers.append(attachment)
            }
        }
    }
    
    private var listLayers: [CALayer] = []
    
    internal func updateListStyle() {
        listLayers.forEach { $0.removeFromSuperlayer() }
        listLayers.removeAll()
        
        let attributedText = self.textStorage
        
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(
            .blockType,
            in: fullRange,
            options: []
        ) {
            value,
            range,
            _ in
            guard value as? String == "list" else { return }
            var index: [UUID: [Int: Int]] = [:]
            attributedText.enumerateAttribute(
                .metadata,
                in: range,
                options: []
            ) {
                value,
                range,
                _ in
                let rect = rectForLine(range: range)
                guard let rect = rect else { return }
                
                guard let value = value as? [String: Any] else { return }
                guard let level = value["level"] as? Int else { return }
                guard let ordered = value["ordered"] as? Bool else { return }
                guard let parentID = value["parentID"] as? UUID else { return }
                
                if ordered {
                    var subIndex = index[parentID] ?? [:]
                    if subIndex[level] == nil {
                        subIndex[level] = 0
                    } else {
                        subIndex[level]! += 1
                    }
                    index[parentID] = subIndex
                }
                
                let style = ordered ? getOrderedListStyle(level: level, index: index[parentID]![level]!) : getUnorderedListStyle(
                    level: level
                )
                
                let levelOffset = CGFloat(level) * 24
                
                let label = UILabel()
                label.text = style
                label.font = UIFont.systemFont(ofSize: 16)
                label.sizeToFit()
                let renderer = UIGraphicsImageRenderer(size: label.bounds.size)
                let image = renderer.image { ctx in
                    label.layer.render(in: ctx.cgContext)
                }
                let attachment = CALayer()
                attachment.contents = image.cgImage
                attachment.frame = CGRect(
                    x: textContainerInset.left + 8 + levelOffset,
                    y: rect.midY - label.bounds.height / 2,
                    width: label.bounds.width,
                    height: label.bounds.height
                )
                
                self.layer.insertSublayer(attachment, at: 0)
                
                listLayers.append(attachment)
            }
        }
    }
    
    private func getUnorderedListStyle(level: Int) -> String {
        switch level % 3 {
        case 0:
            return "• "
        case 1:
            return "◦ "
        case 2:
            return "▪ "
        default:
            return ""
        }
    }
    
    private func getOrderedListStyle(level: Int, index: Int) -> String {
        switch level % 3 {
        case 0:
            return "\(index + 1). "
        case 1:
            let letters = Array("abcdefghijklmnopqrstuvwxyz")
            var result = ""
            var n = index
            
            repeat {
                let charIndex = n % 26
                result = String(letters[charIndex]) + result
                n = n / 26 - 1
            } while n >= 0
            
            return result + ". "
        case 2:
            let romanNumerals: [(Int, String)] = [
                (1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
                (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
                (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")
            ]
            
            var result = ""
            var number = index + 1
            for (value, numeral) in romanNumerals {
                while number >= value {
                    result += numeral
                    number -= value
                }
            }
            return "\(result). "
        default:
            return ""
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        self.delegate = self
    }
    
    private func getMetadataRange(id: UUID) -> NSRange? {
        var range: NSRange?
        self.textStorage.enumerateAttribute(
            .metadata,
            in: NSRange(location: 0, length: self.textStorage.length),
            options: []
        ) {
            value, r, stop in
            guard let value = value as? [String: Any] else { return }
            if value["id"] as? UUID == id {
                range = r
                stop.pointee = true
            }
        }
        return range
    }
    
    private func getBlockRange(id: UUID) -> NSRange? {
        var range: NSRange?
        self.textStorage.enumerateAttribute(
            .blockID,
            in: NSRange(location: 0, length: self.textStorage.length),
            options: []
        ) {
            value, r, stop in
            if value as? UUID == id {
                range = r
                stop.pointee = true
            }
        }
        return range
    }
    
    func removeBlockquote(lineRange: NSRange) {
        self.textStorage.addAttributes([
            .blockID: UUID(),
            .blockType: "paragraph",
        ], range: lineRange)
        self.textStorage.removeAttribute(.paragraphStyle, range: lineRange)
        // remove the zero-width character
        self.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: NSAttributedString())
    }
    
    func removeListItemInBlockquote(itemRange: NSRange) {
        self.textStorage.removeAttribute(.metadata, range: itemRange)
        self.textStorage.addAttributes([
            .paragraphStyle: BlockquoteContent.getParagraphStyle(level: 0)
        ], range: itemRange)
        // 不知道为什么在删除metadata后渲染出现了问题
        DispatchQueue.main.async(execute: {
            self.updateBlockquoteStyle()
            self.updateListStyle()
        })
    }
    
    func removeListItem(itemRange: NSRange) {
        let newAttribute: [NSAttributedString.Key: Any] = [
            .blockID: UUID(),
            .blockType: "paragraph"
        ]
        self.textStorage.addAttributes(newAttribute, range: itemRange)
        self.textStorage.removeAttribute(.metadata, range: itemRange)
        self.textStorage.removeAttribute(.paragraphStyle, range: itemRange)
        // remove the zero-width character
        self.textStorage.replaceCharacters(in: NSRange(location: itemRange.location, length: 1), with: NSAttributedString())
        // 不知道为什么在删除metadata后渲染出现了问题
        DispatchQueue.main.async(execute: {
            self.updateBlockquoteStyle()
            self.updateListStyle()
        })
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let blockID = self.typingAttributes[.blockID] as? UUID
        if text == "\n" {
            // 添加一个换行符
            guard let blockType = self.typingAttributes[.blockType] as? String else {
                return false
            }
            let metadata = self.typingAttributes[.metadata] as? [String: Any]
            
            switch blockType {
            case "heading":
                // TODO: create a new paragraph block
                fallthrough
            case "paragraph":
                // TODO: insert a new line
                fallthrough
            case "blockquote":
                if metadata == nil {
                    // insert a new line
                    let linebreak = NSAttributedString(
                        string: "\n",
                        attributes: self.typingAttributes
                    )
                    self.textStorage.replaceCharacters(in: range, with: linebreak)
                    // insert a zero-width character
                    let last = NSRange(
                        location: range.location + linebreak.length,
                        length: 0
                    )
                    let zeroWidthChar = NSAttributedString(
                        string: "\u{200B}",
                        attributes: self.typingAttributes
                    )
                    self.textStorage.replaceCharacters(in: last, with: zeroWidthChar)
                    // move cursor to the next line
                    self.selectedRange = NSRange(
                        location: range.location + linebreak.length + zeroWidthChar.length,
                        length: 0
                    )
                    self.updateDocument(blockID: blockID!)
                } else {
                    // new line from list item
                    fallthrough
                }
            case "list":
                if metadata != nil {
                    let itemRange = getMetadataRange(
                        id: metadata!["id"] as! UUID
                    )
                    guard let itemRange = itemRange else { return false }
                    if itemRange.location + 1 == range.location {
                        // 在item开头按回车
                        if blockType == "list" {
                            self.removeListItem(itemRange: itemRange)
                            // move cursor
                            self.selectedRange = NSRange(
                                location: range.location - 1,
                                length: 0
                            )
                        } else if blockType == "blockquote" {
                            self.removeListItemInBlockquote(itemRange: itemRange)
                        }
                        return false
                    }
                    // find the rest of the item and set to new metadata
                    var newAttribute = self.typingAttributes
                    var newMetadata = metadata!
                    newMetadata["id"] = UUID()
                    newAttribute[.metadata] = newMetadata
                    let restRange = NSRange(
                        location: range.location,
                        length: itemRange.location + itemRange.length - range.location
                    )
                    self.textStorage.addAttributes([
                        .metadata: newMetadata
                    ], range: restRange)
                    // inset a linebreak with the old metadata
                    let linebreak = NSAttributedString(
                        string: "\n",
                        attributes: self.typingAttributes
                    )
                    self.textStorage.replaceCharacters(in: range, with: linebreak)
                    
                    // insert a zero-width character
                    let last = NSRange(
                        location: range.location + linebreak.length,
                        length: 0
                    )
                    let zeroWidthChar = NSAttributedString(
                        string: "\u{200B}",
                        attributes: newAttribute
                    )
                    self.textStorage.replaceCharacters(in: last, with: zeroWidthChar)
                    
                    // move cursor to the next line
                    self.selectedRange = NSRange(
                        location: range.location + linebreak.length + zeroWidthChar.length,
                        length: 0
                    )
                    // set typing attributes
                    self.typingAttributes = newAttribute
                    self.updateDocument(blockID: blockID!)
                }
            default:
                break
            }
            return false
        } else if text.isEmpty {
            // 删除文字
            let blockID = self.typingAttributes[.blockID] as? UUID
            let deletedText = self.textStorage.attributedSubstring(from: range).string
            if deletedText == "\u{200B}" {
                // 删除一个零宽字符
                let attributes = self.textStorage.attributes(
                    at: range.location,
                    effectiveRange: nil
                )
                let metadata = attributes[.metadata] as? [String: Any]
                
                switch attributes[.blockType] as? String {
                case "blockquote":
                    if metadata == nil {
                        if range.location == 0 {
                            let fullText = self.textStorage.string as NSString
                            let lineRange = fullText.lineRange(for: NSRange(location: range.location, length: 0))
                            self.removeBlockquote(lineRange: lineRange)
                            return false
                        }
                        let prevAttributes = self.textStorage.attributes(
                            at: range.location - 1,
                            effectiveRange: nil
                        )
                        guard let prevBlockID = prevAttributes[.blockID] as? UUID else {
                            // illegal state
                            return false
                        }
                        let fullText = self.textStorage.string as NSString
                        let lineRange = fullText.lineRange(for: NSRange(location: range.location + 1, length: 0))
                        if prevBlockID == blockID {
                            let prevMetadata = prevAttributes[.metadata] as? [String: Any]
                            if prevMetadata == nil {
                                // remove the zero-width character
                                self.textStorage.replaceCharacters(
                                    in: NSRange(location: range.location - 1, length: 2),
                                    with: NSAttributedString()
                                )
                                // move cursor
                                self.selectedRange = NSRange(
                                    location: range.location - 1,
                                    length: 0
                                )
                            } else {
                                let paragraphStyle = prevAttributes[.paragraphStyle] as? NSParagraphStyle
                                self.textStorage.addAttributes([
                                    .metadata: prevMetadata!,
                                    .paragraphStyle: paragraphStyle!
                                ], range: lineRange)
                                
                                // remove linebreak and zero-width character
                                self.textStorage.replaceCharacters(in: NSRange(location: range.location - 1, length: 2), with: NSAttributedString())
                                // move cursor
                                self.selectedRange = NSRange(
                                    location: range.location - 1,
                                    length: 0
                                )
                                self.updateDocument(blockID: blockID!)
                            }
                        } else {
                            self.removeBlockquote(lineRange: lineRange)
                            // move cursor
                            self.selectedRange = NSRange(
                                location: range.location,
                                length: 0
                            )
                            self.updateDocument(blockID: blockID!)
                        }
                        return false
                    } else {
                        let itemRange = getMetadataRange(
                            id: metadata!["id"] as! UUID
                        )
                        guard let itemRange = itemRange else { return false }
                        
                        let level = metadata!["level"] as! Int
                        if level - 1 > 0 {
                            var newMetadata = metadata!
                            newMetadata["level"] = level - 1
                            let curr = self.document.getBlockquote(metadata!["parentID"] as! UUID)!
                            let parent = self.document.getBlockquote(curr.parentID!)!
                            newMetadata["ordered"] = parent.ordered
                            newMetadata["parentID"] = parent.id
                            // set to new metadata
                            self.textStorage.addAttributes([
                                .metadata: newMetadata,
                                .paragraphStyle: BlockquoteContent.getParagraphStyle(level: level - 1),
                            ], range: itemRange)
                            self.updateDocument(blockID: blockID!)
                        } else {
                            self.removeListItemInBlockquote(itemRange: itemRange)
                        }
                        self.updateDocument(blockID: blockID!)
                        return false
                    }
                case "list":
                    let itemRange = getMetadataRange(id: metadata!["id"] as! UUID)
                    guard let itemRange = itemRange else { return false }
                    
                    let level = metadata!["level"] as! Int
                    if level - 1 >= 0 {
                        var newMetadata = metadata!
                        newMetadata["level"] = level - 1
                        let curr = self.document.getList(metadata!["parentID"] as! UUID)!
                        let parent = self.document.getList(curr.parentID!)!
                        newMetadata["ordered"] = parent.ordered
                        newMetadata["parentID"] = parent.id
                        
                        self.textStorage.addAttributes([
                            .metadata: newMetadata,
                            .paragraphStyle: ListContent.getParagraphStyle(level: level - 1)
                        ], range: itemRange)
                        self.updateDocument(blockID: blockID!)
                        self.updateListStyle()
                        return false
                    }
                    if range.location == 0 {
                        // 在开头的List的第一个item删除零宽字符
                        self.removeListItem(itemRange: itemRange)
                        // move cursor
                        self.selectedRange = NSRange(
                            location: range.location,
                            length: 0
                        )
                        self.updateDocument(blockID: blockID!)
                        return false
                    }
                    
                    let prevAttributes = self.textStorage.attributes(
                        at: range.location - 1,
                        effectiveRange: nil
                    )
                    guard let prevBlockID = prevAttributes[.blockID] as? UUID else {
                        // illegal state
                        return false
                    }
                    if prevBlockID == blockID {
                        let prevMetadata = prevAttributes[.metadata] as? [String: Any]
                        self.textStorage.addAttribute(
                            .metadata,
                            value: prevMetadata!,
                            range: itemRange
                        )
                        // remove the linebreak
                        self.textStorage.replaceCharacters(in: NSRange(location: range.location - 1, length: 2), with: NSAttributedString())
                        self.selectedRange = NSRange(
                            location: range.location - 1,
                            length: 0
                        )
                        self.updateDocument(blockID: blockID!)
                        return false
                    } else if prevAttributes[.blockType] as? String == "list" {
                        // change this item to the prev list
                        let prevMetadata = prevAttributes[.metadata] as? [String: Any]
                        let paragraphStyle = prevAttributes[.paragraphStyle] as? NSParagraphStyle
                        self.textStorage.addAttributes([
                            .blockID: prevBlockID,
                            .metadata: prevMetadata,
                            .paragraphStyle: paragraphStyle
                        ], range: itemRange)
                        // remove the linebreak
                        self.textStorage.replaceCharacters(in: NSRange(location: range.location - 1, length: 2), with: NSAttributedString())
                        self.selectedRange = NSRange(
                            location: range.location - 1,
                            length: 0
                        )
                        self.updateDocument(blockID: blockID!)
                        return false
                    } else {
                        // 在List的第一个item最前方删除零宽字符
                        self.removeListItem(itemRange: itemRange)
                        // move cursor
                        self.selectedRange = NSRange(
                            location: range.location,
                            length: 0
                        )
                        self.updateDocument(blockID: blockID!)
                        return false
                    }
                    break
                default:
                    break
                }
            } else if deletedText == "\n" {
                // 删除一个换行符
                let prevAttribute = self.textStorage.attributes(
                    at: range.location,
                    effectiveRange: nil
                )
                
                switch self.typingAttributes[.blockType] as? String {
                case "paragraph":
                    let blockID = self.typingAttributes[.blockID] as? UUID
                    let blockRange = getBlockRange(id: blockID!)
                    guard let blockRange = blockRange else { return false }
                    
                    let prevBlockID = prevAttribute[.blockID] as? UUID
                    let prevBlockType = prevAttribute[.blockType] as? String
                    self.textStorage.addAttributes([
                        .blockID: prevBlockID!,
                        .blockType: prevBlockType!
                    ], range: blockRange)
                    let metadata = prevAttribute[.metadata] as? [String: Any]
                    let paragraphStyle = prevAttribute[.paragraphStyle] as? NSParagraphStyle
                    if metadata != nil {
                        self.textStorage.addAttributes([
                            .metadata: metadata!,
                        ], range: blockRange)
                    }
                    if paragraphStyle != nil {
                        self.textStorage.addAttributes([
                            .paragraphStyle: paragraphStyle!
                        ], range: blockRange)
                    }
                    self.updateDocument(blockID: blockID!)
                default:
                    break
                }
            } else {
                // 删除其它内容
            }
        } else {
            // 添加文字
            let styled = NSAttributedString(string: text, attributes: self.typingAttributes)
            self.textStorage.replaceCharacters(in: range, with: styled)
            let newPosition = range.location + styled.length
            self.selectedRange = NSRange(location: newPosition, length: 0)
            self.updateDocument(blockID: blockID!)
            return false
        }
        return true
    }
    
    private var previousSelectedRange: NSRange?
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        let cursor = self.selectedRange.location
        let length = self.textStorage.length
        
        var newTypingAttributes: [NSAttributedString.Key: Any]
        
        // 光标在已有文字中，取当前位置属性
        if length > 0 && cursor < length {
            newTypingAttributes = self.textStorage.attributes(at: cursor, effectiveRange: nil)
        }
        // 光标在末尾但文档非空，继承最后一个字符属性
        else if length > 0 && cursor == length {
            newTypingAttributes = self.textStorage.attributes(at: cursor - 1, effectiveRange: nil)
        }
        // 光标在空文档中，使用默认样式
        else {
            newTypingAttributes = [
                .blockID: UUID(),
                .blockType: "paragraph",
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label,
            ]
        }
        DispatchQueue.main.async {
            textView.typingAttributes = newTypingAttributes
            // 通知 toolbar 更新按钮状态
            Toolbar.shared.updateButtonStates(basedOn: newTypingAttributes)
        }
        if self.selectedRange.length == 0 {
            let fullText = self.textStorage.string as NSString
            let lineRange = fullText.lineRange(for: NSRange(location: cursor, length: 0))
            if lineRange.length != 0 && cursor == lineRange.location {
                if cursor != self.textStorage.length - 1 && self.textStorage.attributedSubstring(from: NSRange(location: cursor, length: 1)).string == "\u{200B}" {
                    if previousSelectedRange != nil && previousSelectedRange!.location == cursor + 1 {
                        let newPosition = max(1, cursor - 1)
                        self.selectedRange = NSRange(
                            location: newPosition,
                            length: 0
                        )
                        print("[ZeroWidthChar] Move to prev line")
                    } else {
                        self.selectedRange = NSRange(
                            location: cursor + 1,
                            length: 0
                        )
                        print("[ZeroWidthChar] Move to next character")
                    }
                }
            }
        }
        self.previousSelectedRange = self.selectedRange
    }
    
    func updateDocument(blockID: UUID) {
        var blockRange: NSRange?
        self.textStorage.enumerateAttribute(
            .blockID,
            in: NSRange(location: 0, length: self.textStorage.length),
            options: []
        ) {
            value, range, stop in
            if value as? UUID != blockID {
                return
            }
            stop.pointee = true
            blockRange = range
        }
        if blockRange == nil {
            self.document.blocks.removeValue(forKey: blockID)
            return
        }
        let blockType = self.textStorage.attributes(at: blockRange!.location, effectiveRange: nil)[.blockType] as? String
        
        let content = self.textStorage.attributedSubstring(from: blockRange!)
        let fullText = content.string as NSString
        
        var block: Block
        switch blockType {
        case "heading":
            var fragments: [InlineTextFragment] = []
            let font = content.attributes(at: 0, effectiveRange: nil)[.font] as! UIFont
            let level: Int = {
                switch font.pointSize {
                // TODO: Use rem instead of fixed size
                case 32: return 1
                case 24: return 2
                case 18.72: return 3
                case 16: return 4
                case 13.28: return 5
                case 10.72: return 6
                default: return 4
                }
            }()
            content.enumerateAttributes(in: NSRange(location: 0, length: content.length), options: []) { attributes, range, _ in
                let substring = content.attributedSubstring(from: range)
                let fragment = self.toInlineTextFragment(substring.string, attributes: attributes)
                fragments.append(fragment)
            }
            block = .heading(level: level, content: fragments)
        case "paragraph":
            var fragments: [InlineTextFragment] = []
            content.enumerateAttributes(in: NSRange(location: 0, length: content.length), options: []) { attributes, range, _ in
                let substring = content.attributedSubstring(from: range)
                let fragment = self.toInlineTextFragment(substring.string, attributes: attributes)
                fragments.append(fragment)
            }
            block = .paragraph(content: fragments)
        case "blockquote":
            let blockquoteContent = BlockquoteContent(document: self.document, parentID: nil, items: [])
            
            var contents: [UUID: BlockquoteContent] = [:]
            content.enumerateAttribute(.metadata, in: NSRange(location: 0, length: content.length), options: []) { value, itemRange, _ in
                let item = content.attributedSubstring(from: itemRange)
                
                let fragments: [InlineTextFragment] = {
                    var localFragments: [InlineTextFragment] = []
                    item.enumerateAttributes(in: NSRange(location: 0, length: item.length), options: []) { substringAttribute, substringRange, _ in
                        let substring = item.attributedSubstring(from: substringRange)
                        let text = substring.string.replacingOccurrences(of: "\u{200B}", with: "")
                        let fragment = self.toInlineTextFragment(text, attributes: substringAttribute)
                        localFragments.append(fragment)
                    }
                    return localFragments
                }()
                
                let metadata = value as? [String: Any]
                if metadata == nil {
                    // default content in blockquote
                    blockquoteContent.items.append(.text(content: fragments))
                } else {
                    let id = metadata!["id"] as! UUID
                    let parentID = metadata!["parentID"] as! UUID
                    let level = metadata!["level"] as! Int
                    let ordered = metadata!["ordered"] as! Bool
                    
                    if contents[parentID] == nil {
                        let contentParentID: UUID
                        if level == 1 {
                            contentParentID = blockquoteContent.id
                        } else {
                            // This must be updated when increasing/decreasing indent
                            contentParentID = self.document.getBlockquote(parentID)!.parentID!
                        }
                        contents[parentID] = BlockquoteContent(document: self.document, parentID: contentParentID, items: [], ordered: ordered)
                        blockquoteContent.items.append(.list(content: contents[parentID]!))
                    }
                    let currentContent = contents[parentID]!
                    
                    currentContent.items.append(.text(content: fragments))
                }
            }
            block = .blockquote(content: blockquoteContent)
        case "list":
            var listContent = ListContent(document: self.document, parentID: nil, items: [])
            
            var contents: [UUID: ListContent] = [:]
            content.enumerateAttribute(.metadata, in: NSRange(location: 0, length: content.length), options: []) { value, itemRange, _ in
                let item = content.attributedSubstring(from: itemRange)
                
                let metadata = value as! [String: Any]
                let id = metadata["id"] as! UUID
                let parentID = metadata["parentID"] as! UUID
                let level = metadata["level"] as! Int
                let ordered = metadata["ordered"] as! Bool
                
                let fragments: [InlineTextFragment] = {
                    var localFragments: [InlineTextFragment] = []
                    item.enumerateAttributes(in: NSRange(location: 0, length: item.length), options: []) { substringAttribute, substringRange, _ in
                        let substring = item.attributedSubstring(from: substringRange)
                        let text = substring.string.replacingOccurrences(of: "\u{200B}", with: "")
                        let fragment = self.toInlineTextFragment(text, attributes: substringAttribute)
                        localFragments.append(fragment)
                    }
                    return localFragments
                }()
                if level == 0 {
                    listContent.items.append(.text(content: fragments))
                    listContent.ordered = ordered
                } else {
                    if contents[parentID] == nil {
                        let contentParentID: UUID?
                        // This must be updated when increasing/decreasing indent
                        contentParentID = self.document.getList(parentID)!.parentID!
                        contents[parentID] = ListContent(document: self.document, id: parentID, parentID: contentParentID, items: [], ordered: ordered)
                        listContent.items.append(.list(content: contents[parentID]!))
                    }
                    let currentContent = contents[parentID]!
                    currentContent.items.append(.text(content: fragments))
                }
            }
            block = .list(content: listContent)
        default:
            return
        }
        
        self.document.blocks[blockID] = block
    }
    
    private func toInlineTextFragment(_ string: String, attributes: [NSAttributedString.Key: Any]) -> InlineTextFragment {
        let font = attributes[.font] as? UIFont
        let isBold = font != nil && font!.isBold
        let isItalic = font != nil && font!.isItalic
        let isUnderline = attributes[.underlineStyle] != nil && attributes[.underlineStyle] as! Int == 1
        let textColor = attributes[.foregroundColor] as? UIColor
        let fragment = InlineTextFragment(text: string, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline, textColor: textColor)
        return fragment
    }
}
