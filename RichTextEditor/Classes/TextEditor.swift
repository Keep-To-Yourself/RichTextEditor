//
//  TextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

class TextEditor: UITextView {
    
    private let editor: RichTextEditor
    private let storage: DocumentTextStorage
    
    init(_ editor: RichTextEditor) {
        self.editor = editor
        
        let doc = Document(blocks: [
            IdentifiedBlock(block: .heading(level: 1, content: [InlineTextFragment(text: "标题", isBold: true, isItalic: false, isUnderline: false, textColor: .blue)])),
            IdentifiedBlock(block: .paragraph([InlineTextFragment(text: "正文内容", isBold: false, isItalic: true, isUnderline: true, textColor: nil)])),
            IdentifiedBlock(block: .blockquote([
                .paragraph([InlineTextFragment(text: "引用内容", isBold: false, isItalic: false, isUnderline: false, textColor: nil)]),
            ])),
            IdentifiedBlock(block: .unorderedList([
                ListItem(content: [.paragraph([InlineTextFragment(text: "项目一", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])]),
                ListItem(content: [.paragraph([InlineTextFragment(text: "项目二", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])]),
                ListItem(content: [
                    .unorderedList([
                        ListItem(content: [
                            .paragraph([InlineTextFragment(text: "嵌套项目", isBold: false, isItalic: true, isUnderline: false, textColor: nil)])
                        ]),
                        ListItem(content: [
                            .paragraph([InlineTextFragment(text: "嵌套项目2", isBold: true, isItalic: false, isUnderline: false, textColor: nil)])
                        ])
                    ])
                ])
            ])),
            IdentifiedBlock(block: .orderedList([
                ListItem(content: [.paragraph([InlineTextFragment(text: "有序项目一", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])]),
                ListItem(content: [.paragraph([InlineTextFragment(text: "有序项目二", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])]),
                ListItem(content: [.orderedList([
                    ListItem(content: [
                        .paragraph([InlineTextFragment(text: "嵌套有序\n项目", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])
                    ])
                ])])
            ]))
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
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let textRange = textRange(from: start, to: end) else { return nil }
        
        let rects = selectionRects(for: textRange).compactMap { $0 as? UITextSelectionRect }.map { $0.rect }
        return rects.reduce(CGRect.null) { $0.union($1) }
    }
    
    private var blockquoteLayers: [Int: [CAShapeLayer]] = [:]
    
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
    
    private func updateBlockquoteStyle() {
        // 删除所有旧图层
        blockquoteLayers.values.flatMap { $0 }.forEach { $0.removeFromSuperlayer() }
        blockquoteLayers.removeAll()
        
        // 获取所有 blockquote 范围
        let attributedText = self.storage.backingStore
        
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
        for (index, range) in ranges.enumerated() {
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
            }
            
            blockquoteLayers[index] = layers
        }
    }
    
    private var listLayers: [CALayer] = []
    
    private func updateListStyle() {
        listLayers.forEach { $0.removeFromSuperlayer() }
        listLayers.removeAll()
        
        // 获取所有 list
        let attributedText = self.storage
        
        var ranges = [NSRange]()
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(
            .listLevel,
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }
            ranges.append(range)
        }
        
        for range in ranges {
            let firstCharRange = NSRange(location: range.location, length: 1)
            let rect = rectForTextRange(range: firstCharRange)
            guard let rect = rect else { continue }
            
            // 列表等级
            let level = attributedText.attribute(.listLevel, at: range.location, effectiveRange: nil)
            guard let level = level as? Int else { continue }
            
            // 列表样式
            let style = attributedText.attribute(.listStyle, at: range.location, effectiveRange: nil)
            guard let style = style as? String else { continue }
            
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
