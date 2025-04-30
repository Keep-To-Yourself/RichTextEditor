//
//  RichTextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/29.
//

import UIKit

public class RichTextEditor: UIView {
    
    private var textView: TextEditor!
    private var configuration: RichTextEditorConfiguration
    public var onFocusChanged: ((Bool) -> Void)?

    override public init(frame: CGRect) {
        self.configuration = RichTextEditorConfiguration()
        super.init(frame: frame)
        
        textView = TextEditor(self)
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        self.setConfiguration(self.configuration)
        
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
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
}
