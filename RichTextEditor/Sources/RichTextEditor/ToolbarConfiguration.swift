//
//  ToolbarConfiguration.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

public struct ToolbarConfiguration {
    
    /// Toolbar 的高度
    public var height: CGFloat
    
    /// 背景颜色
    public var backgroundColor: UIColor
    
    public init(
        height: CGFloat = 44,
        backgroundColor: UIColor = .systemGray6
    ) {
        self.height = height
        self.backgroundColor = backgroundColor
    }
}
