//
//  TextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

class TextEditor: UITextView, UITextViewDelegate {
    
    private let editor: RichTextEditor
    private let storage: DocumentTextStorage
    
    init(_ editor: RichTextEditor) {
        self.editor = editor
        
        let doc = Document(blocks: [
            IdentifiedBlock(block: .heading(level: 1, content: [InlineTextFragment(text: "标题\n", isBold: true, isItalic: false, isUnderline: false, textColor: .blue)])),
            IdentifiedBlock(block: .paragraph(content: [InlineTextFragment(text: "正文内容\n", isBold: false, isItalic: true, isUnderline: true, textColor: nil)])),
            IdentifiedBlock(block: .blockquote(content: BlockquoteContent(items: [
                .text(content: [InlineTextFragment(text: "引用内容\n", isBold: false, isItalic: false, isUnderline: false, textColor: nil)]),
                .list(content: BlockquoteContent(items: [
                    .text(content:[InlineTextFragment(text: "引用+列表\n", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])
                ]))
            ]))),
            IdentifiedBlock(block: .list(content: ListContent(items: [
                .text(content:[
                    InlineTextFragment(text: "项目一\n", isBold: false, isItalic: false, isUnderline: false, textColor: nil)
                ]),
                .text(content:[
                    InlineTextFragment(text: "项目二\n", isBold: false, isItalic: false, isUnderline: false, textColor: nil)
                ]),
                .list(content: ListContent(items: [
                    .text(content:[InlineTextFragment(text: "嵌套项目\n", isBold: false, isItalic: true, isUnderline: false, textColor: nil)]),
                    .text(content:[InlineTextFragment(text: "嵌套项目2\n", isBold: true, isItalic: false, isUnderline: false, textColor: nil)])
                ]))
            ]))),
            IdentifiedBlock(block: .list(content: ListContent(items: [
                .text(content:[InlineTextFragment(text: "有序项目一\n", isBold: false, isItalic: false, isUnderline: false, textColor: nil)]),
                .text(content:[InlineTextFragment(text: "有序项目二\n", isBold: false, isItalic: false, isUnderline: false, textColor: nil)]),
                .list(content: ListContent(items: [
                    .text(content:[InlineTextFragment(text: "嵌套有序\n项目", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])
                ]))
            ], ordered: true)))
        ])
        self.storage = DocumentTextStorage(document: doc)
        
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        self.storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        super.init(frame: .zero, textContainer: textContainer)
        
        self.storage.apply()
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
    
    private func updateBlockquoteStyle() {
        // 删除所有旧图层
        blockquoteLayers.forEach { $0.removeFromSuperlayer() }
        blockquoteLayers.removeAll()
        
        // 获取所有 blockquote 范围
        let attributedText = self.storage
        
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
            backgroundLayer.fillColor = UIColor.systemGray6.withAlphaComponent(0.8).cgColor
            layers.append(backgroundLayer)
            
            // 竖线
            let lineLayer = CAShapeLayer()
            let lineRect = CGRect(x: fullLineMinX, y: y, width: 6, height: height)
            let linePath = UIBezierPath(rect: lineRect)
            lineLayer.path = linePath.cgPath
            lineLayer.fillColor = UIColor.systemGray2.cgColor
            layers.append(lineLayer)
            
            // 添加到视图
            for layer in layers {
                self.layer.insertSublayer(layer, at: 0)
                
                blockquoteLayers.append(layer)
            }
            
            var index: [Int: Int] = [:]
            
            attributedText.enumerateAttribute(
                .metadata,
                in: range,
                options: []
            ) { value, range, _ in
                let rect = rectForLine(range: range)
                guard let rect = rect else { return }
                
                guard let value = value as? [String: Any] else { return }
                guard let level = value["level"] as? Int else { return }
                guard let ordered = value["ordered"] as? Bool else { return }
                
                if index[level] == nil {
                    index[level] = 0
                } else {
                    index[level]! += 1
                }
                
                let style = ordered ? getOrderedListStyle(level: level - 1, index: index[level]!) : getUnorderedListStyle(level: level - 1)
                
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
    
    private func updateListStyle() {
        listLayers.forEach { $0.removeFromSuperlayer() }
        listLayers.removeAll()
        
        let attributedText = self.storage
        
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(
            .blockType,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard value as? String == "list" else { return }
            var index: [Int: Int] = [:]
            attributedText.enumerateAttribute(
                .metadata,
                in: range,
                options: []
            ) { value, range, _ in
                let rect = rectForLine(range: range)
                guard let rect = rect else { return }
                
                guard let value = value as? [String: Any] else { return }
                guard let level = value["level"] as? Int else { return }
                guard let ordered = value["ordered"] as? Bool else { return }
                
                if ordered {
                    if index[level] == nil {
                        index[level] = 0
                    } else {
                        index[level]! += 1
                    }
                }
                
                let style = ordered ? getOrderedListStyle(level: level, index: index[level]!) : getUnorderedListStyle(level: level)
                
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
        self.storage.enumerateAttribute(.metadata, in: NSRange(location: 0, length: self.storage.length), options: []) {
            value, r, stop in
            guard let value = value as? [String: Any] else { return }
            if value["id"] as? UUID == id {
                range = r
                stop.pointee = true
            }
        }
        return range
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            // TODO: 处理多个换行
            // TODO: 处理range.location == 0的情况
            let prevAttribute = self.storage.attributes(at: range.location - 1, effectiveRange: nil)
            
            guard let blockType = prevAttribute[.blockType] as? String else { return false }
            let metadata = prevAttribute[.metadata] as? [String: Any]
            
            switch blockType {
            case "heading":
                // create a new paragraph block
                fallthrough
            case "paragraph":
                // insert a new line
                fallthrough
            case "blockquote":
                if metadata == nil {
                    self.storage.insert(NSAttributedString(string: "\n", attributes: prevAttribute), at: range.location)
                    // move cursor to the next line
                    self.selectedRange = NSRange(location: range.location + 1, length: 0)
                    // TODO:
                } else {
                    // new line from list item
                    fallthrough
                }
            case "list":
                if metadata != nil {
                    let itemRange = getMetadataRange(id: metadata!["id"] as! UUID)
                    guard let itemRange = itemRange else { return false }
                    // find the rest of the item and set to new metadata
                    let restRange = NSRange(location: range.location, length: itemRange.location + itemRange.length - range.location)
                    //                    print("restRange: \(restRange)")
                    //                    print(self.storage.attributedSubstring(from: restRange))
                    if restRange.length == 0 {
                        // TODO: 边界情况：在最后一个item添加新行
                        print("A")
                    }else{
                        // apply new metadata to the rest of the item
                        var newAttribute = prevAttribute
                        var newMetadata = metadata!
                        newMetadata["id"] = UUID()
                        newAttribute[.metadata] = newMetadata
                        self.storage.addAttributes(newAttribute, range: restRange)
                        
                        // inset a linebreak with the old metadata
                        self.storage.insert(NSAttributedString(string: "\n", attributes: prevAttribute), at: range.location)
                        
                        // move cursor to the next line
                        self.selectedRange = NSRange(location: range.location + 1, length: 0)
                        
                        // set typing attributes
                        if let typedAttributes = newAttribute as? [String: Any] {
                            self.typingAttributes = typedAttributes
                        }
                    }
                }
            default:
                break
            }
            return false
        } else if text.isEmpty {
            if self.storage.attributedSubstring(from: range).string == "\n" {
                let attributes = self.storage.attributes(at: range.location, effectiveRange: nil)
                
                guard let blockType = attributes[.blockType] as? String else { return false }
                
                switch blockType {
                case "blockquote":
                    fallthrough
                case "list":
                    if range.location + 1 < self.storage.length {
                        let nextAttributes = self.storage.attributes(at: range.location + 1, effectiveRange: nil)
                        guard let nextBlockType = nextAttributes[.blockType] as? String else { return false }
                        
                        if nextBlockType == blockType {
                            let metadata = nextAttributes[.metadata] as? [String: Any]
                            if metadata != nil {
                                // find the rest of the item and set to new metadata
                                let itemRange = getMetadataRange(id: metadata!["id"] as! UUID)
                                guard let itemRange = itemRange else { return false }
                                
                                let restRange = NSRange(location: range.location, length: itemRange.location + itemRange.length - range.location)
                                // apply new metadata to the rest of the item
                                self.storage.setAttributes(attributes, range: restRange)
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
        return true
    }
}
