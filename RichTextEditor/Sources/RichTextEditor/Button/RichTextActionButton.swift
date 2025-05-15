//
//  RichTextActionButton.swift
//  RichTextEditor
//
//  Created by 易汉斌 on 2025/5/15.
//

import UIKit

public class RichTextActionButton: UIButton {
	public let action: RichTextAction

	// 点击事件的回调闭包，Toolbar 或其他容器可以设置这个回调
	public var onTap: ((RichTextAction) -> Void)?

	public init(action: RichTextAction, frame: CGRect = .zero) { // frame 通常由 AutoLayout 处理
		self.action = action
		super.init(frame: frame) // 调用父类 UIButton 的 init
		
		setupDisplayContent()
		self.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
		
		// 基础样式，可以根据需要调整或在 Toolbar 中统一设置
		self.tintColor = .label // 对于 SF Symbols，tintColor 控制颜色
		if self.title(for: .normal) != nil {
			self.setTitleColor(.label, for: .normal)
			self.setTitleColor(.systemGray, for: .highlighted)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupDisplayContent() {
		let displayContent = action.getDefaultButtonDisplayContent()
		
		if let image = displayContent.image {
			self.setImage(image, for: .normal)
			// (可选) 为按钮设置合适的内边距或调整 imageEdgeInsets，使图标看起来更好
			// self.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
		} else if let title = displayContent.title {
			self.setTitle(title, for: .normal)
			// 根据标题设置字体，例如
			switch action {
			case .bold:
				self.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
			case .italic:
				self.titleLabel?.font = UIFont.italicSystemFont(ofSize: 17) // 注意：系统没有直接的 italicSystemFont，通常是描述符实现
																		  // 先用普通字体占位
				self.titleLabel?.font = UIFont.systemFont(ofSize: 17)
			default:
				self.titleLabel?.font = UIFont.systemFont(ofSize: 17)
			}
		}
	}

	@objc private func buttonTapped() {
		// 调用回调闭包，并传递自己的 action 类型
		onTap?(self.action)
		// TODO: 按钮的选中状态反馈 (例如点击后高亮，或根据编辑器状态更新选中)
		// 比如： self.isSelected.toggle() 或 self.backgroundColor = .lightGray
		// 实际的功能绑定会在后续步骤进行。
	}
	
	// 预留一个方法，用于根据编辑器当前状态更新按钮的 UI (例如是否高亮)
	public func updateVisualState(isActive: Bool) {
		// TODO: 根据 isActive 状态改变按钮外观，比如背景色、tintColor 等
		// self.isSelected = isActive // UIButton 有 isSelected 状态
		// self.backgroundColor = isActive ? UIColor.systemGray4 : UIColor.clear
		self.alpha = isActive ? 1.0 : 0.5 // 简单示例
	}
}
