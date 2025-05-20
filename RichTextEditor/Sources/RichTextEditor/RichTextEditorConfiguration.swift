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
    
    func getHeadingSize(level: Int) -> CGFloat {
        switch level {
        case 1: return 2 * self.fontSize
        case 2: return 1.5 * self.fontSize
        case 3: return 1.17 * self.fontSize
        case 4: return 1 * self.fontSize
        case 5: return 0.83 * self.fontSize
        case 6: return 0.67 * self.fontSize
        default: return 1 * self.fontSize
        }
    }
}
