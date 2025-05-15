//
//  RichTextEditorConfiguration.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

public struct RichTextEditorConfiguration {
    
    /// 字体大小
    public var fontSize: CGFloat
    /// 字体颜色
    public var textColor: UIColor
    /// 背景颜色
    public var backgroundColor: UIColor
    
    public init(
        fontSize: CGFloat = 16,
        textColor: UIColor = .black,
        backgroundColor: UIColor = .white
    ) {
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
}
