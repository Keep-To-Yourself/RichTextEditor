//
//  RichTextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/29.
//

import UIKit

public class RichTextEditor: UIView {
    
    internal var textView: TextEditor!
    internal var configuration: RichTextEditorConfiguration
    public var onFocusChanged: ((Bool) -> Void)?
    
    public init(
        configuration: RichTextEditorConfiguration,
        document: Document? = nil
    ) {
        self.configuration = configuration
        super.init(frame: .zero)
        
        var doc = document ?? Document()
        if document == nil {
            doc.blocks[UUID()] = .list(
                content: ListContent(
                    document: doc,
                    parentID: nil,
                    items: [
                        .text(
                            content: [
                                InlineTextFragment(
                                    text: "项目一\n",
                                    isBold: false,
                                    isItalic: false,
                                    isUnderline: false,
                                    textColor: nil
                                )
                            ]
                        ),
                        .text(
                            content: [
                                InlineTextFragment(
                                    text: "项目二\n",
                                    isBold: false,
                                    isItalic: false,
                                    isUnderline: false,
                                    textColor: nil
                                )
                            ]
                        ),
                    ]
                )
            )
            doc.blocks[UUID()] =
                .heading(
                    level: 1,
                    content: [
                        InlineTextFragment(
                            text: "标题\n",
                            isBold: true,
                            isItalic: false,
                            isUnderline: false,
                            textColor: .blue
                        )
                    ]
                )
            doc.blocks[UUID()] =
                .paragraph(
                    content: [
                        InlineTextFragment(
                            text: "正文内容\n",
                            isBold: false,
                            isItalic: true,
                            isUnderline: true,
                            textColor: nil
                        )
                    ]
                )
            let blockquoteContent = BlockquoteContent(
                document: doc,
                parentID: nil,
                items: [
                    .text(
                        content: [
                            InlineTextFragment(
                                text: "引用内容\n",
                                isBold: false,
                                isItalic: false,
                                isUnderline: false,
                                textColor: nil
                            )
                        ]
                    )
                ]
            )
            let blockquoteContentSubList = BlockquoteContent(
                document: doc,
                parentID: blockquoteContent.id,
                items: [
                    .text(content: [
                        InlineTextFragment(
                            text: "引用+列表\n",
                            isBold: false,
                            isItalic: false,
                            isUnderline: false,
                            textColor: nil
                        )
                    ]
                         )
                ]
            )
            blockquoteContent.items.append(
                .list(content: blockquoteContentSubList)
            )
            blockquoteContent.items.append(
                .text(content: [
                    InlineTextFragment(
                        text: "引用内容\n",
                        isBold: false,
                        isItalic: false,
                        isUnderline: false,
                        textColor: nil
                    )
                ])
            )
            doc.blocks[UUID()] = .blockquote(content: blockquoteContent)
            let listContent = ListContent(
                document: doc,
                parentID: nil,
                items: [
                    .text(content: [
                        InlineTextFragment(
                            text: "列表内容\n",
                            isBold: false,
                            isItalic: false,
                            isUnderline: false,
                            textColor: nil
                        )
                    ]),
                    .text(content: [
                        InlineTextFragment(
                            text: "嵌套\n",
                            isBold: false,
                            isItalic: false,
                            isUnderline: false,
                            textColor: nil
                        )
                    ]),
                ],
                ordered: true
            )
            let listContentSubList = ListContent(
                document: doc,
                parentID: listContent.id,
                items: [
                    .text(content: [
                        InlineTextFragment(
                            text: "嵌套列表\n",
                            isBold: false,
                            isItalic: false,
                            isUnderline: false,
                            textColor: nil
                        ),
                        InlineTextFragment(
                            text: "嵌套\n列表",
                            isBold: false,
                            isItalic: false,
                            isUnderline: false,
                            textColor: nil
                        )
                    ])
                ],
                ordered: true
            )
            listContent.items.append(.list(content: listContentSubList))
            doc.blocks[UUID()] = .list(content: listContent)
        }
        
        textView = TextEditor(self, document: doc)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setConfiguration(_ configuration: RichTextEditorConfiguration) {
        self.configuration = configuration
        textView.font = UIFont.systemFont(ofSize: configuration.fontSize)
        textView.textColor = configuration.textColor
        textView.backgroundColor = configuration.backgroundColor
    }
    
    public func getDocument() -> Document {
        return self.textView.document
    }
    
    public func toggleBold() {
        textView.toggleBold()
    }
    
    public func toggleItalic() {
        textView.toggleItalic()
    }
    
    public func toggleUnderline() {
        textView.toggleUnderline()
    }
    
    public func toggleStrikethrough() {
        textView.toggleStrikethrough()
    }
    
    public func toggleBlockquote() {
        textView.toggleBlockquote()
    }
    
    public func toggleOrderedList() {
        textView.toggleOrderedList()
    }
    
    public func toggleUnorderedList() {
        textView.toggleUnorderedList()
    }
    
    public func increaseIndent() {
        textView.increaseIndent()
    }
    
    public func decreaseIndent() {
        textView.decreaseIndent()
    }
    
    public func applyHeading(level: Int) {
        textView.applyHeading(level: level)
    }
    
    public func applyParagraph() {
        textView.applyParagraph()
    }
}
