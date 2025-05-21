//
//  TextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit
import Collections

class TextEditor: UITextView, UITextViewDelegate {
    
    let editor: RichTextEditor
    let document: Document
    
    init(_ editor: RichTextEditor, document: Document) {
        self.editor = editor
        self.document = document
        
        super.init(frame: .zero, textContainer: nil)
        
        self.textStorage.setAttributedString(document.toAttributedString(configuration: self.editor.configuration))
        self.autocapitalizationType = .none
        self.autocorrectionType = .no
        self.smartDashesType = .no
        self.smartQuotesType = .no
        self.smartInsertDeleteType = .no
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
        let glyphRange = self.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = self.layoutManager.boundingRect(forGlyphRange: glyphRange, in: self.textContainer)
        return CGRect(
            x: rect.origin.x + textContainerInset.left,
            y: rect.origin.y + textContainerInset.top,
            width: rect.width,
            height: rect.height
        )
    }
    
    private func rectForLine(range: NSRange) -> CGRect? {
        let glyphRange = self.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = self.layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
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
    
    func updateBlockquoteStyle() {
        // 删除所有旧图层
        blockquoteLayers.forEach { $0.removeFromSuperlayer() }
        blockquoteLayers.removeAll()
        
        // 获取所有 blockquote 范围
        let attributedText = self.textStorage
        
        var ranges = [NSRange]()
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(.blockType, in: fullRange, options: [] ) { value, range, _ in
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
            
            attributedText.enumerateAttribute(.metadata, in: range, options: []) { value, range, _ in
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
                label.font = UIFont.systemFont(ofSize: self.editor.configuration.fontSize)
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
    
    func updateListStyle() {
        listLayers.forEach { $0.removeFromSuperlayer() }
        listLayers.removeAll()
        
        let attributedText = self.textStorage
        
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(.blockType, in: fullRange, options: []) { value, range, _ in
            guard value as? String == "list" else { return }
            var index: [UUID: [Int: Int]] = [:]
            attributedText.enumerateAttribute(.metadata, in: range, options: []) { value, range, _ in
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
        self.textStorage.enumerateAttribute(.metadata, in: NSRange(location: 0, length: self.textStorage.length), options: []) { value, r, stop in
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
        self.textStorage.enumerateAttribute(.blockID, in: NSRange(location: 0, length: self.textStorage.length), options: []) { value, r, stop in
            if value as? UUID == id {
                range = r
                stop.pointee = true
            }
        }
        return range
    }
    
    func removeBlockquote(lineRange: NSRange) {
        // move the following items to a new blockquote
        let attributes = self.textStorage.attributes(at: lineRange.location, effectiveRange: nil)
        let blockID = attributes[.blockID] as! UUID
        let newBlockID = UUID()
        let blockRange = getBlockRange(id: blockID)
        guard let blockRange = blockRange else { return }
        let fullText = self.textStorage.string as NSString
        var from = lineRange.location + lineRange.length
        var end = blockRange.location + blockRange.length
        
        while from < end {
            let lineRange = fullText.lineRange(for: NSRange(location: from, length: 0))
            self.textStorage.addAttributes([
                .blockID: newBlockID,
            ], range: lineRange)
            from = lineRange.upperBound
        }
        
        // create a paragraph block
        let id = UUID()
        self.textStorage.addAttributes([
            .blockID: id,
            .blockType: "paragraph",
        ], range: lineRange)
        self.textStorage.removeAttribute(.paragraphStyle, range: lineRange)
        // remove the zero-width character
        self.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 1), with: NSAttributedString())
        
        // update document
        let oldIndex = self.document.blocks.index(forKey: blockID)!
        self.updateDocument(blockID: blockID)
        let index = self.document.blocks.index(forKey: blockID)
        if index == nil {
            self.updateDocument(blockID: id, index: oldIndex)
            self.updateDocument(blockID: newBlockID, index: oldIndex + 1)
        } else {
            self.updateDocument(blockID: id, index: index! + 1)
            self.updateDocument(blockID: newBlockID, index: index! + 2)
        }
        
        self.updateBlockquoteStyle()
    }
    
    func removeListItemInBlockquote(itemRange: NSRange) {
        // move the following items to a new list
        let attributes = self.textStorage.attributes(at: itemRange.location, effectiveRange: nil)
        let blockID = attributes[.blockID] as! UUID
        let blockRange = getBlockRange(id: blockID)
        guard let blockRange = blockRange else { return }
        let fullText = self.textStorage.string as NSString
        let from = itemRange.location + itemRange.length
        let end = blockRange.location + blockRange.length
        
        var idMapper: [UUID: UUID] = [:]
        
        let current = self.document.getBlockquote((attributes[.metadata] as! [String: Any])["parentID"] as! UUID)!
        var blockquoteRoot = current
        while blockquoteRoot.parentID != nil {
            blockquoteRoot = self.document.getBlockquote(blockquoteRoot.parentID!)!
        }
        let root = BlockquoteContent(document: self.document, id: UUID(), parentID: blockquoteRoot.id, items: [], ordered: false)
        func inCurrent(metadata: [String: Any]) -> Bool {
            var chain: [UUID] = []
            var parentID = metadata["parentID"] as? UUID
            while parentID != nil {
                chain.append(parentID!)
                parentID = self.document.getBlockquote(parentID!)?.parentID
            }
            return chain.contains(current.id)
        }
        self.textStorage.enumerateAttribute(.metadata, in: NSRange(location: from, length: end - from), options: []) { value, range, _ in
            guard let metadata = value as? [String: Any] else { return }
            if !inCurrent(metadata: metadata) {
                return
            }
            let parentID = metadata["parentID"] as! UUID
            let level = metadata["level"] as! Int
            let ordered = metadata["ordered"] as! Bool
            
            var newMetadata = metadata
            if level == 1 {
                idMapper[parentID] = root.id
                root.ordered = ordered
            } else {
                let content = self.document.getList(parentID)!
                if idMapper[content.parentID!] == nil {
                    // switch to a level 0 item
                    idMapper[parentID] = root.id
                    newMetadata["level"] = 1
                } else {
                    let newID = UUID()
                    BlockquoteContent(document: self.document, id: newID, parentID: idMapper[content.parentID!]!, items: [], ordered: ordered)
                    idMapper[parentID] = newID
                }
            }
            let newParentID = idMapper[parentID]!
            newMetadata["parentID"] = newParentID
            
            self.textStorage.addAttributes([
                .metadata: newMetadata,
            ], range: range)
        }
        
        self.textStorage.removeAttribute(.metadata, range: itemRange)
        self.textStorage.addAttributes([
            .paragraphStyle: BlockquoteContent.getParagraphStyle(level: 0)
        ], range: itemRange)
        DispatchQueue.main.async(execute: {
            self.updateBlockquoteStyle()
            self.updateListStyle()
        })
        
        // update document
        self.updateDocument(blockID: blockID)
        
        self.updateBlockquoteStyle()
    }
    
    func removeListItem(itemRange: NSRange) {
        // move the following items to a new list
        let attributes = self.textStorage.attributes(at: itemRange.location, effectiveRange: nil)
        let blockID = attributes[.blockID] as! UUID
        let blockRange = getBlockRange(id: blockID)
        guard let blockRange = blockRange else { return }
        let fullText = self.textStorage.string as NSString
        let from = itemRange.location + itemRange.length
        let end = blockRange.location + blockRange.length
        
        var idMapper: [UUID: UUID] = [:]
        
        let newBlockID = UUID()
        let root = ListContent(document: self.document, id: UUID(), parentID: nil, items: [], ordered: false)
        self.textStorage.enumerateAttribute(.metadata, in: NSRange(location: from, length: end - from), options: []) { value, range, _ in
            let metadata = value as! [String: Any]
            let parentID = metadata["parentID"] as! UUID
            let level = metadata["level"] as! Int
            let ordered = metadata["ordered"] as! Bool
            
            var newMetadata = metadata
            if level == 0 {
                idMapper[parentID] = root.id
                root.ordered = ordered
            } else {
                let content = self.document.getList(parentID)!
                if idMapper[content.parentID!] == nil {
                    // switch to a level 0 item
                    idMapper[parentID] = root.id
                    newMetadata["level"] = 0
                } else {
                    let newID = UUID()
                    ListContent(document: self.document, id: newID, parentID: idMapper[content.parentID!]!, items: [], ordered: ordered)
                    idMapper[parentID] = newID
                }
            }
            let newParentID = idMapper[parentID]!
            newMetadata["parentID"] = newParentID
            
            self.textStorage.addAttributes([
                .blockID: newBlockID,
                .metadata: newMetadata,
            ], range: range)
        }
        
        // create a paragraph block
        let id = UUID()
        let newAttribute: [NSAttributedString.Key: Any] = [
            .blockID: id,
            .blockType: "paragraph"
        ]
        self.textStorage.addAttributes(newAttribute, range: itemRange)
        self.textStorage.removeAttribute(.metadata, range: itemRange)
        self.textStorage.removeAttribute(.paragraphStyle, range: itemRange)
        // remove the zero-width character
        self.textStorage.replaceCharacters(in: NSRange(location: itemRange.location, length: 1), with: NSAttributedString())
        DispatchQueue.main.async(execute: {
            self.updateBlockquoteStyle()
            self.updateListStyle()
        })
        
        // update document
        let oldIndex = self.document.blocks.index(forKey: blockID)!
        self.updateDocument(blockID: blockID)
        let index = self.document.blocks.index(forKey: blockID)
        if index == nil {
            self.updateDocument(blockID: id, index: oldIndex)
            self.updateDocument(blockID: newBlockID, index: oldIndex + 1)
        } else {
            self.updateDocument(blockID: id, index: index! + 1)
            self.updateDocument(blockID: newBlockID, index: index! + 2)
        }
        self.updateListStyle()
    }
    
    func toHeading(level: Int, lineRange: NSRange) {
        let id = UUID()
        let index: Int
        if lineRange.location == 0 {
            index = 0
        } else {
            let prevAttribute = self.textStorage.attributes(at: lineRange.location - 1, effectiveRange: nil)
            let prevBlockID = prevAttribute[.blockID] as! UUID
            index = self.document.blocks.index(forKey: prevBlockID)! + 1
        }
        let metadata = [
            "level": level,
        ]
        let attributes: [NSAttributedString.Key: Any] = [
            .blockID: id,
            .blockType: "heading",
            .metadata: metadata,
            .font: UIFont.systemFont(ofSize: self.editor.configuration.getHeadingSize(level: level)).withTraits(traits: .traitBold),
        ]
        
        if lineRange.length == 0 {
            // add attributes
            self.textStorage.addAttributes(attributes, range: lineRange)
        } else {
            let currAttribute = self.textStorage.attributes(at: lineRange.location, effectiveRange: nil)
            let currBlockID = currAttribute[.blockID] as! UUID
            
            // add attributes
            self.textStorage.addAttributes(attributes, range: lineRange)
            self.updateDocument(blockID: currBlockID)
        }
        
        self.updateDocument(blockID: id, index: index)
    }
    
    func toBlockquote(lineRange: NSRange) {
        let id = UUID()
        let index: Int
        if lineRange.location == 0 {
            index = 0
        } else {
            let prevAttribute = self.textStorage.attributes(at: lineRange.location - 1, effectiveRange: nil)
            let prevBlockID = prevAttribute[.blockID] as! UUID
            index = self.document.blocks.index(forKey: prevBlockID)! + 1
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .blockID: id,
            .blockType: "blockquote",
            .paragraphStyle: BlockquoteContent.getParagraphStyle(level: 0),
            .font: UIFont.systemFont(ofSize: self.editor.configuration.fontSize),
        ]
        
        if lineRange.length == 0 {
            let zeroWidthCharacter = NSAttributedString(string: "\u{200B}", attributes: attributes)
            // add attributes
            self.textStorage.addAttributes(attributes, range: lineRange)
            // insert the zero-width character
            self.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: zeroWidthCharacter)
        } else {
            let currAttribute = self.textStorage.attributes(at: lineRange.location, effectiveRange: nil)
            let currBlockID = currAttribute[.blockID] as! UUID
            
            let zeroWidthCharacter = NSAttributedString(string: "\u{200B}", attributes: attributes)
            // add attributes
            self.textStorage.addAttributes(attributes, range: lineRange)
            // insert the zero-width character
            self.textStorage.replaceCharacters(in: NSRange(location: lineRange.location, length: 0), with: zeroWidthCharacter)
            
            self.updateDocument(blockID: currBlockID)
        }
        self.updateDocument(blockID: id, index: index)
        self.updateBlockquoteStyle()
    }
    
    func toBlockquoteListItem(itemRange: NSRange, ordered: Bool) {
        let attributes = self.textStorage.attributes(at: itemRange.location, effectiveRange: nil)
        let blockID = attributes[.blockID] as! UUID
        if itemRange.location > 0 {
            let prevAttribute = self.textStorage.attributes(at: itemRange.location - 1, effectiveRange: nil)
            let metadata = prevAttribute[.metadata] as? [String: Any]
            if metadata == nil || metadata!["ordered"] as! Bool != ordered {
                self.textStorage.addAttributes([
                    .blockID: blockID,
                    .blockType: "blockquote",
                    .metadata: [
                        "id": UUID(),
                        "level": 1,
                        "ordered": ordered,
                        "parentID": UUID()
                    ],
                    .paragraphStyle: BlockquoteContent.getParagraphStyle(level: 1),
                ], range: itemRange)
            } else {
                let level = metadata!["level"] as! Int
                self.textStorage.addAttributes([
                    .blockID: blockID,
                    .blockType: "blockquote",
                    .metadata: [
                        "id": UUID(),
                        "level": level,
                        "ordered": ordered,
                        "parentID": metadata!["parentID"]!
                    ],
                    .paragraphStyle: BlockquoteContent.getParagraphStyle(level: level),
                ], range: itemRange)
            }
        } else {
            self.textStorage.addAttributes([
                .blockID: blockID,
                .blockType: "blockquote",
                .metadata: [
                    "id": UUID(),
                    "level": 1,
                    "ordered": ordered,
                    "parentID": UUID()
                ],
                .paragraphStyle: BlockquoteContent.getParagraphStyle(level: 1),
            ], range: itemRange)
        }
        self.updateDocument(blockID: blockID)
        self.updateBlockquoteStyle()
    }
    
    func toListItem(itemRange: NSRange, ordered: Bool) {
        let id: UUID
        let index: Int
        let attributes: [NSAttributedString.Key: Any]
        if itemRange.location == 0 {
            id = UUID()
            attributes = [
                .blockID: id,
                .blockType: "list",
                .metadata: [
                    "id": UUID(),
                    "level": 0,
                    "ordered": ordered,
                    "parentID": UUID()
                ],
                .paragraphStyle: ListContent.getParagraphStyle(level: 0),
                .font: UIFont.systemFont(ofSize: self.editor.configuration.fontSize),
            ]
            index = 0
        } else {
            let prevAttribute = self.textStorage.attributes(at: itemRange.location - 1, effectiveRange: nil)
            let prevBlockID = prevAttribute[.blockID] as! UUID
            let prevBlockType = prevAttribute[.blockType] as! String
            let metadata = prevAttribute[.metadata] as? [String: Any]
            if prevBlockType == "list" && metadata != nil && metadata!["ordered"] as! Bool == ordered && metadata!["level"] as! Int == 0 {
                id = prevBlockID
                attributes = [
                    .blockID: id,
                    .blockType: "list",
                    .metadata: [
                        "id": UUID(),
                        "level": 0,
                        "ordered": ordered,
                        "parentID": metadata!["parentID"] as! UUID
                    ],
                    .paragraphStyle: ListContent.getParagraphStyle(level: 0),
                    .font: UIFont.systemFont(ofSize: self.editor.configuration.fontSize),
                ]
            } else {
                id = UUID()
                attributes = [
                    .blockID: id,
                    .blockType: "list",
                    .metadata: [
                        "id": UUID(),
                        "level": 0,
                        "ordered": ordered,
                        "parentID": UUID()
                    ],
                    .paragraphStyle: ListContent.getParagraphStyle(level: 0),
                    .font: UIFont.systemFont(ofSize: self.editor.configuration.fontSize),
                ]
            }
            index = self.document.blocks.index(forKey: prevBlockID)! + 1
        }
        
        if itemRange.length == 0 {
            // add attributes
            self.textStorage.addAttributes(attributes, range: itemRange)
            
            // insert a zero-width character
            let zeroWidthCharacter = NSAttributedString(string: "\u{200B}", attributes: attributes)
            self.textStorage.replaceCharacters(in: NSRange(location: itemRange.location, length: 0), with: zeroWidthCharacter)
            
        } else {
            let currAttribute = self.textStorage.attributes(at: itemRange.location, effectiveRange: nil)
            let currBlockID = currAttribute[.blockID] as! UUID
            
            // add attributes
            self.textStorage.addAttributes(attributes, range: itemRange)
            
            // insert a zero-width character
            let zeroWidthCharacter = NSAttributedString(string: "\u{200B}", attributes: attributes)
            self.textStorage.replaceCharacters(in: NSRange(location: itemRange.location, length: 0), with: zeroWidthCharacter)
            
            self.updateDocument(blockID: currBlockID)
        }
        self.updateDocument(blockID: id, index: index)
        self.updateListStyle()
    }
    
    var attributes: [NSAttributedString.Key: Any]?
    var range: NSRange?
    var toUpdate: [UUID]?
    
    func textViewDidChange(_ textView: UITextView) {
        if self.markedTextRange != nil {
            return
        }
        guard let toUpdate = toUpdate else { return }
        
        if self.attributes != nil && self.range != nil {
            let attributedText = NSMutableAttributedString(attributedString: textView.attributedText)
            print(attributedText)
            attributedText.setAttributes(attributes!, range: range!)
            textView.attributedText = attributedText
        }
        for blockID in toUpdate {
            self.updateDocument(blockID: blockID)
        }
        self.toUpdate = nil
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.typingAttributes = self.getDefaultAttribute()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        self.attributes = nil
        self.range = nil
        self.toUpdate = nil
        let fullText = self.textStorage.string as NSString
        if text.isEmpty {
            // 删除文字
            let deletedContent = self.textStorage.attributedSubstring(from: range)
            if deletedContent.length == 0 {
                return true
            }
            let deletedText = deletedContent.string
            let attributes = deletedContent.attributes(at: 0, effectiveRange: nil)
            let blockID = attributes[.blockID] as? UUID
            guard let blockID = blockID else {
                // probably using input method
                return true
            }
            let blockType = attributes[.blockType] as! String
            if deletedText == "\u{200B}" {
                // 删除一个零宽字符
                let metadata = attributes[.metadata] as? [String: Any]
                
                switch blockType {
                case "blockquote":
                    if metadata == nil {
                        if range.location == 0 {
                            let fullText = self.textStorage.string as NSString
                            let lineRange = fullText.lineRange(for: NSRange(location: range.location, length: 0))
                            self.removeBlockquote(lineRange: lineRange)
                            return false
                        }
                        let prevAttributes = self.textStorage.attributes(at: range.location - 1, effectiveRange: nil)
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
                                self.textStorage.replaceCharacters(in: NSRange(location: range.location - 1, length: 2), with: NSAttributedString())
                                // move cursor
                                self.selectedRange = NSRange(location: range.location - 1, length: 0)
                            } else {
                                let paragraphStyle = prevAttributes[.paragraphStyle] as? NSParagraphStyle
                                self.textStorage.addAttributes([
                                    .metadata: prevMetadata!,
                                    .paragraphStyle: paragraphStyle!
                                ], range: lineRange)
                                
                                // remove linebreak and zero-width character
                                self.textStorage.replaceCharacters(in: NSRange(location: range.location - 1, length: 2), with: NSAttributedString())
                                // move cursor
                                self.selectedRange = NSRange(location: range.location - 1, length: 0)
                            }
                            self.updateDocument(blockID: blockID)
                        } else {
                            self.removeBlockquote(lineRange: lineRange)
                            // move cursor
                            self.selectedRange = NSRange(
                                location: range.location,
                                length: 0
                            )
                        }
                        return false
                    } else {
                        let metadata = metadata!
                        let itemRange = getMetadataRange(id: metadata["id"] as! UUID)!
                        
                        let level = metadata["level"] as! Int
                        if level - 1 > 0 {
                            var newMetadata = metadata
                            newMetadata["level"] = level - 1
                            let curr = self.document.getBlockquote(metadata["parentID"] as! UUID)!
                            let parent = self.document.getBlockquote(curr.parentID!)!
                            newMetadata["ordered"] = parent.ordered
                            newMetadata["parentID"] = parent.id
                            // set to new metadata
                            self.textStorage.addAttributes([
                                .metadata: newMetadata,
                                .paragraphStyle: BlockquoteContent.getParagraphStyle(level: level - 1),
                            ], range: itemRange)
                            self.updateDocument(blockID: blockID)
                        } else {
                            self.removeListItemInBlockquote(itemRange: itemRange)
                        }
                        return false
                    }
                case "list":
                    let metadata = metadata!
                    let itemRange = getMetadataRange(id: metadata["id"] as! UUID)!
                    
                    let level = metadata["level"] as! Int
                    if level - 1 >= 0 {
                        var newMetadata = metadata
                        newMetadata["level"] = level - 1
                        let curr = self.document.getList(metadata["parentID"] as! UUID)!
                        let parent = self.document.getList(curr.parentID!)!
                        newMetadata["ordered"] = parent.ordered
                        newMetadata["parentID"] = parent.id
                        
                        self.textStorage.addAttributes([
                            .metadata: newMetadata,
                            .paragraphStyle: ListContent.getParagraphStyle(level: level - 1)
                        ], range: itemRange)
                        self.updateDocument(blockID: blockID)
                        return false
                    }
                    if range.location == 0 {
                        // 在开头的List的第一个item删除零宽字符
                        self.removeListItem(itemRange: itemRange)
                        // move cursor
                        self.selectedRange = NSRange(location: range.location, length: 0)
                        self.updateDocument(blockID: blockID)
                        return false
                    }
                    
                    let prevAttributes = self.textStorage.attributes(at: range.location - 1, effectiveRange: nil)
                    guard let prevBlockID = prevAttributes[.blockID] as? UUID else {
                        // illegal state
                        return false
                    }
                    if prevBlockID == blockID {
                        let prevMetadata = prevAttributes[.metadata] as? [String: Any]
                        self.textStorage.addAttribute(.metadata,value: prevMetadata!, range: itemRange)
                        // remove the linebreak
                        self.textStorage.replaceCharacters(in: NSRange(location: range.location - 1, length: 2), with: NSAttributedString())
                        self.selectedRange = NSRange(location: range.location - 1, length: 0)
                        self.updateDocument(blockID: blockID)
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
                        self.selectedRange = NSRange(location: range.location - 1, length: 0)
                        self.updateDocument(blockID: blockID)
                        return false
                    } else {
                        // 在List的第一个item最前方删除零宽字符
                        self.removeListItem(itemRange: itemRange)
                        // move cursor
                        self.selectedRange = NSRange(location: range.location,length: 0)
                        self.updateDocument(blockID: blockID)
                        return false
                    }
                    break
                default:
                    break
                }
            } else if deletedText == "\n" {
                if range.location == self.textStorage.length - 1 {
                    // remove the linebreak
                    self.textStorage.replaceCharacters(in: range, with: NSAttributedString())
                    // move cursor
                    self.selectedRange = NSRange(location: range.location, length: 0)
                    // update document
                    self.updateDocument(blockID: blockID)
                    return false
                }
                let lineRange = fullText.lineRange(for: NSRange(location: range.location + 1, length: 0))
                let paragraphAttributes = self.attributedText.attributes(at: lineRange.location, effectiveRange: nil)
                switch blockType {
                case "list":
                    let metadata = attributes[.metadata] as! [String: Any]
                    
                    let level = metadata["level"] as! Int
                    // add attributes
                    self.textStorage.addAttributes([
                        .blockType: "list",
                        .blockID: blockID,
                        .metadata: metadata,
                        .paragraphStyle: ListContent.getParagraphStyle(level: level),
                    ], range: lineRange)
                    // remove the linebreak
                    self.textStorage.replaceCharacters(in: range, with: NSAttributedString())
                    // move cursor
                    self.selectedRange = NSRange(location: range.location, length: 0)
                    // update document
                    self.updateDocument(blockID: blockID)
                    self.updateDocument(blockID: paragraphAttributes[.blockID] as! UUID)
                    return false
                case "blockquote":
                    let metadata = attributes[.metadata] as? [String: Any]
                    if metadata == nil {
                        // add attributes
                        self.textStorage.addAttributes([
                            .blockType: "blockquote",
                            .blockID: blockID,
                            .paragraphStyle: BlockquoteContent.getParagraphStyle(level: 0),
                        ], range: lineRange)
                        // remove the linebreak
                        self.textStorage.replaceCharacters(in: range, with: NSAttributedString())
                        // move cursor
                        self.selectedRange = NSRange(location: range.location, length: 0)
                        // update document
                        self.updateDocument(blockID: blockID)
                        self.updateDocument(blockID: paragraphAttributes[.blockID] as! UUID)
                    } else {
                        let metadata = attributes[.metadata] as! [String: Any]
                        
                        let level = metadata["level"] as! Int
                        // add attributes
                        self.textStorage.addAttributes([
                            .blockType: "blockquote",
                            .blockID: blockID,
                            .metadata: metadata,
                            .paragraphStyle: BlockquoteContent.getParagraphStyle(level: level),
                        ], range: lineRange)
                        // remove the linebreak
                        self.textStorage.replaceCharacters(in: range, with: NSAttributedString())
                        // move cursor
                        self.selectedRange = NSRange(location: range.location, length: 0)
                        // update document
                        self.updateDocument(blockID: blockID)
                        self.updateDocument(blockID: paragraphAttributes[.blockID] as! UUID)
                    }
                    return false
                case "heading":
                    let metadata = attributes[.metadata] as! [String: Any]
                    let level = metadata["level"] as! Int
                    // add attributes
                    self.textStorage.addAttributes([
                        .blockType: "heading",
                        .blockID: blockID,
                        .metadata: metadata,
                        .font: UIFont.systemFont(ofSize: self.editor.configuration.getHeadingSize(level: level)).withTraits(traits: .traitBold),
                    ], range: lineRange)
                    // remove the linebreak
                    self.textStorage.replaceCharacters(in: range, with: NSAttributedString())
                    // move cursor
                    self.selectedRange = NSRange(location: range.location, length: 0)
                    // update document
                    self.updateDocument(blockID: blockID)
                    self.updateDocument(blockID: paragraphAttributes[.blockID] as! UUID)
                    return false
                default:
                    // remove the linebreak
                    self.textStorage.replaceCharacters(in: range, with: NSAttributedString())
                    // move cursor
                    self.selectedRange = NSRange(location: range.location, length: 0)
                    // update document
                    self.updateDocument(blockID: blockID)
                    return false
                }
            } else {
                var ids: Set<UUID> = []
                deletedContent.enumerateAttribute(.blockID, in: NSRange(location: 0, length: deletedContent.length), options: []) { value, r, _ in
                    guard let value = value as? UUID else { return }
                    ids.insert(value)
                }
                self.toUpdate = Array(ids)
            }
        } else {
            // 添加文字
            let attributes: [NSAttributedString.Key: Any]
            if self.textStorage.length > 0 && range.location < self.textStorage.length {
                // 光标在已有文字中，取当前位置属性
                attributes = self.textStorage.attributes(at: range.location, effectiveRange: nil)
            } else if self.textStorage.length > 0 && range.location == self.textStorage.length {
                // get line length
                let fullText = self.textStorage.string as NSString
                let lineRange = fullText.lineRange(for: NSRange(location: range.location, length: 0))
                if lineRange.length == 0 {
                    attributes = self.getDefaultAttribute()
                } else {
                    // 光标在末尾但文档非空，继承最后一个字符属性
                    attributes = self.textStorage.attributes(at: range.location - 1, effectiveRange: nil)
                }
            } else {
                // 光标在空文档中，使用默认样式
                attributes = self.getDefaultAttribute()
            }
            
            let blockID = attributes[.blockID] as! UUID
            let blockType = attributes[.blockType] as! String
            
            if text == "\n" {
                // 添加一个换行符
                let metadata = attributes[.metadata] as? [String: Any]
                
                switch blockType {
                case "heading":
                    // get the rest of the heading
                    let lineRange = fullText.lineRange(for: NSRange(location: range.location, length: 0))
                    let restRange = NSRange(location: range.location, length: lineRange.location + lineRange.length - range.location)
                    // add attributes
                    let id = UUID()
                    let newAttributes: [NSAttributedString.Key: Any] = [
                        .blockID: id,
                        .blockType: "paragraph",
                        .font: UIFont.systemFont(ofSize: self.editor.configuration.fontSize),
                    ]
                    self.textStorage.addAttributes(newAttributes, range: restRange)
                    
                    // insert linebreak
                    let linebreak = NSAttributedString(string: "\n", attributes: attributes)
                    self.textStorage.replaceCharacters(in: range, with: linebreak)
                    // move cursor to the next line
                    self.selectedRange = NSRange(location: range.location + linebreak.length, length: 0)
                    // update document
                    self.updateDocument(blockID: blockID)
                    self.updateDocument(blockID: id, index: self.document.blocks.index(forKey: blockID)! + 1)
                    // update typing attributes
                    self.typingAttributes = newAttributes
                    return false
                case "paragraph":
                    let linebreak = NSAttributedString(string: "\n", attributes: attributes)
                    // insert linebreak
                    self.textStorage.replaceCharacters(in: range, with: linebreak)
                    // move cursor to the next line
                    self.selectedRange = NSRange(location: range.location + linebreak.length, length: 0)
                    self.updateDocument(blockID: blockID)
                    return false
                case "blockquote":
                    if metadata == nil {
                        // insert a new line
                        let linebreak = NSAttributedString(string: "\n", attributes: attributes)
                        self.textStorage.replaceCharacters(in: range, with: linebreak)
                        // insert a zero-width character
                        let last = NSRange(location: range.location + linebreak.length, length: 0)
                        let zeroWidthChar = NSAttributedString(string: "\u{200B}", attributes: attributes)
                        self.textStorage.replaceCharacters(in: last, with: zeroWidthChar)
                        // move cursor to the next line
                        self.selectedRange = NSRange(location: range.location + linebreak.length + zeroWidthChar.length, length: 0)
                        self.updateDocument(blockID: blockID)
                    } else {
                        // new line from list item
                        fallthrough
                    }
                case "list":
                    if metadata != nil {
                        let itemRange = getMetadataRange(id: metadata!["id"] as! UUID)
                        guard let itemRange = itemRange else { return false }
                        if itemRange.location + 1 == range.location {
                            // 在item开头按回车
                            if blockType == "list" {
                                self.removeListItem(itemRange: itemRange)
                                // move cursor
                                self.selectedRange = NSRange(location: range.location - 1, length: 0)
                            } else if blockType == "blockquote" {
                                self.removeListItemInBlockquote(itemRange: itemRange)
                            }
                            return false
                        }
                        // find the rest of the item and set to new metadata
                        var newAttribute = attributes
                        var newMetadata = metadata!
                        newMetadata["id"] = UUID()
                        newAttribute[.metadata] = newMetadata
                        let restRange = NSRange(location: range.location, length: itemRange.location + itemRange.length - range.location)
                        self.textStorage.addAttributes([
                            .metadata: newMetadata
                        ], range: restRange)
                        // inset a linebreak with the old metadata
                        let linebreak = NSAttributedString( string: "\n", attributes: attributes)
                        self.textStorage.replaceCharacters(in: range, with: linebreak)
                        
                        // insert a zero-width character
                        let last = NSRange(location: range.location + linebreak.length, length: 0)
                        let zeroWidthChar = NSAttributedString(string: "\u{200B}", attributes: newAttribute)
                        self.textStorage.replaceCharacters(in: last, with: zeroWidthChar)
                        
                        // move cursor to the next line
                        self.selectedRange = NSRange(location: range.location + linebreak.length + zeroWidthChar.length, length: 0)
                        // set typing attributes
                        self.typingAttributes = newAttribute
                        self.updateDocument(blockID: blockID)
                    }
                default:
                    break
                }
                return false
            } else {
                self.attributes = attributes
                self.range = NSRange(location: range.location, length: text.utf16.count)
                self.toUpdate = [blockID]
            }
        }
        return true
    }
    
    private var previousSelectedRange: NSRange?
    
    func textViewDidChangeSelection(_ textView: UITextView) {
        let cursor = self.selectedRange.location
        let length = self.textStorage.length
        
        var newTypingAttributes: [NSAttributedString.Key: Any]
        
        if length > 0 && cursor < length {
            // 光标在已有文字中，取当前位置属性
            newTypingAttributes = self.textStorage.attributes(at: cursor, effectiveRange: nil)
        } else if length > 0 && cursor == length {
            // 光标在末尾但文档非空，继承最后一个字符属性
            newTypingAttributes = self.textStorage.attributes(at: cursor - 1, effectiveRange: nil)
        } else {
            // 光标在空文档中，使用默认样式
            newTypingAttributes = self.getDefaultAttribute()
        }
        self.typingAttributes = newTypingAttributes
        // 通知 toolbar 更新按钮状态
        Toolbar.shared.updateButtonStates(basedOn: newTypingAttributes)
        if self.selectedRange.length == 0 {
            let fullText = self.textStorage.string as NSString
            let lineRange = fullText.lineRange(for: NSRange(location: cursor, length: 0))
            if lineRange.length != 0 && cursor == lineRange.location {
                if cursor != self.textStorage.length && self.textStorage.attributedSubstring(from: NSRange(location: cursor, length: 1)).string == "\u{200B}" {
                    if previousSelectedRange != nil && previousSelectedRange!.location == cursor + 1 {
                        let newPosition = max(1, cursor - 1)
                        self.selectedRange = NSRange(location: newPosition, length: 0)
                        print("[ZeroWidthChar] Move to prev line")
                    } else {
                        self.selectedRange = NSRange(location: cursor + 1, length: 0)
                        print("[ZeroWidthChar] Move to next character")
                    }
                }
            }
        }
        self.previousSelectedRange = self.selectedRange
    }
    
    func updateDocument(blockID: UUID, index: Int? = nil) {
        var blockRange: NSRange?
        self.textStorage.enumerateAttribute(.blockID, in: NSRange(location: 0, length: self.textStorage.length), options: []) { value, range, stop in
            if value as? UUID != blockID {
                return
            }
            stop.pointee = true
            blockRange = range
        }
        if blockRange == nil || blockRange!.length == 0 {
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
            let attributes = content.attributes(at: 0, effectiveRange: nil)
            let level = (attributes[.metadata] as! [String: Any])["level"] as! Int
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
                        contents[parentID] = BlockquoteContent(document: self.document, id: parentID, parentID: contentParentID, items: [], ordered: ordered)
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
        
        if index == nil {
            self.document.blocks[blockID] = block
        } else {
            self.document.blocks.updateValue(block, forKey: blockID, insertingAt: index!)
        }
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
    
    private func getDefaultAttribute() -> [NSAttributedString.Key: Any] {
        return [
            .blockID: UUID(),
            .blockType: "paragraph",
            .font: UIFont.systemFont(ofSize: self.editor.configuration.fontSize),
            .foregroundColor: UIColor.label,
        ]
    }
}
