//
//  RichTextActionButton.swift
//  RichTextEditor
//
//  Created by 易汉斌 on 2025/5/15.
//

import UIKit

public class RichTextActionButton: UIButton {
	public let action: RichTextAction

	public var onTap: ((RichTextAction) -> Void)?

	override public var isSelected: Bool {
		didSet {
			updateAppearance()
		}
	}

	override public var isHighlighted: Bool {
		didSet {
			if !isSelected {
				alpha = isHighlighted ? 0.6 : 1.0
			} else {
				alpha = isHighlighted ? 0.8 : 1.0
			}
		}
	}

	public init(action: RichTextAction, frame: CGRect = .zero) {
		self.action = action
		super.init(frame: frame)

		setupDisplayContent()
		self.addTarget(
			self,
			action: #selector(buttonTapped),
			for: .touchUpInside
		)

		updateAppearance()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupDisplayContent() {
		let displayContent = action.getDefaultButtonDisplayContent()

		if let image = displayContent.image {
			self.setImage(image, for: .normal)
			self.setImage(image.withTintColor(.systemBlue), for: .selected)
			self.setImage(image.withTintColor(.systemGray), for: .highlighted)
			self.imageView?.contentMode = .scaleAspectFit
			self.imageEdgeInsets = UIEdgeInsets(
				top: 1,
				left: 1,
				bottom: 1,
				right: 1
			)  // 调整图标内边距
		} else if let title = displayContent.title {
			self.setTitle(title, for: .normal)
			self.titleLabel?.font = UIFont.systemFont(
				ofSize: 15,
				weight: .medium
			)  // 统一字体
			// 根据 isSelected 状态在 updateAppearance 中设置颜色
		}
	}

	private func updateAppearance() {
		if let title = self.title(for: .normal), !title.isEmpty {
			self.setTitleColor(
				isSelected ? (self.window?.tintColor ?? .systemBlue) : .label,
				for: .normal
			)
			self.backgroundColor =
				isSelected
				? (self.window?.tintColor ?? .systemBlue).withAlphaComponent(
					0.15
				) : .clear
			self.layer.cornerRadius = 5
			self.clipsToBounds = true
		} else if self.image(for: .normal) != nil {
			self.tintColor =
				isSelected ? (self.window?.tintColor ?? .systemBlue) : .label
			self.backgroundColor =
				isSelected
				? (self.window?.tintColor ?? .systemBlue).withAlphaComponent(
					0.15
				) : .clear
			self.layer.cornerRadius = 5
			self.clipsToBounds = true
		}
		self.alpha = 1.0
	}

	@objc private func buttonTapped() {
		// 调用回调闭包，并传递自己的 action 类型
		onTap?(self.action)
		// TODO: 按钮的选中状态反馈 (例如点击后高亮，或根据编辑器状态更新选中)
		// 比如： self.isSelected.toggle() 或 self.backgroundColor = .lightGray
		// 实际的功能绑定会在后续步骤进行。
	}
}
