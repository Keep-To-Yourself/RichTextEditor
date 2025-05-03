//
//  TextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

class TextEditor: UITextView {
    
    private let editor: RichTextEditor
    
    init(_ editor: RichTextEditor) {
        self.editor = editor
        super.init(frame: .zero, textContainer: nil)
        
        let doc = Document(blocks: [
            .heading(level: 1, content: [InlineTextFragment(text: "标题", isBold: true, isItalic: false, isUnderline: false, textColor: .blue)]),
            .paragraph([InlineTextFragment(text: "正文内容", isBold: false, isItalic: false, isUnderline: false, textColor: nil)]),
            .blockquote([
                .paragraph([InlineTextFragment(text: "引用内容", isBold: false, isItalic: false, isUnderline: false, textColor: nil)]),
            ]),
            .unorderedList([
                ListItem(content: [.paragraph([InlineTextFragment(text: "项目一", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])]),
                ListItem(content: [.paragraph([InlineTextFragment(text: "项目二", isBold: false, isItalic: false, isUnderline: false, textColor: nil)])])
            ])
        ])
        self.attributedText = doc.toAttributedString()
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
    
    private var blockquoteLayers: [Int: [CAShapeLayer]] = [:]
    
    // 标记需要更新布局
    override var text: String! {
        didSet { updateDecorations() }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDecorations() // 滚动时更新位置
    }
    
    private func updateDecorations() {
        // 删除所有旧图层
        blockquoteLayers.values.flatMap { $0 }.forEach { $0.removeFromSuperlayer() }
        blockquoteLayers.removeAll()
        
        // 获取所有 blockquote 范围
        guard let attributedText = self.attributedText else { return }
        
        var ranges = [NSRange]()
        let fullRange = NSRange(location: 0, length: attributedText.length)
        
        attributedText.enumerateAttribute(
            NSAttributedString.Key("blockquote"),
            in: fullRange,
            options: []
        ) { value, range, _ in
            guard value != nil else { return }
            ranges.append(range)
        }
        
        // 为每个段落添加装饰
        for (index, range) in ranges.enumerated() {
            // 获取文本范围
            guard let start = position(from: beginningOfDocument, offset: range.location),
                  let end = position(from: start, offset: range.length),
                  let textRange = textRange(from: start, to: end) else { continue }
            let rects = selectionRects(for: textRange).compactMap { $0 as? UITextSelectionRect }.map { $0.rect }
            let rect = rects.reduce(CGRect.null) { $0.union($1) }
            
            // 创建装饰图层
            var layers: [CAShapeLayer] = []
            
            let fullLineMinX = textContainerInset.left + 3
            let fullLineMaxX = bounds.width - textContainerInset.right - 3
            let fullLineWidth = fullLineMaxX - fullLineMinX
            
            // 背景矩形
            let fullLineRect = CGRect(x: fullLineMinX + 6,
                                      y: rect.minY,
                                      width: fullLineWidth,
                                      height: rect.height)
            let backgroundLayer = CAShapeLayer()
            let backgroundPath = UIBezierPath(rect: fullLineRect)
            backgroundLayer.path = backgroundPath.cgPath
            backgroundLayer.fillColor = UIColor.systemGray6.withAlphaComponent(0.8).cgColor
            layers.append(backgroundLayer)
            
            // 竖线
            let lineLayer = CAShapeLayer()
            let lineRect = CGRect(x: fullLineMinX, y: rect.minY, width: 6, height: rect.height)
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
}
