//
//  Toolbar.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/29.
//

import UIKit

public class Toolbar: UIView {

	public static let shared = Toolbar()

	private weak var currentRichTextEditor: RichTextEditor?
	private var configuration: ToolbarConfiguration = ToolbarConfiguration()
	private var toolbarTopConstraint: NSLayoutConstraint?
	private var toolbarHeightConstraint: NSLayoutConstraint?

	// 完成按钮
	private lazy var doneButton: UIButton = {
		let button = UIButton(type: .system)
		button.setTitle("完成", for: .normal)
		button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
		button.addTarget(
			self,
			action: #selector(doneTapped),
			for: .touchUpInside
		)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		button.setContentCompressionResistancePriority(
			.required,
			for: .horizontal
		)
		return button
	}()

	private var actionButtons: [RichTextActionButton] = []

	private lazy var buttonsStackView: UIStackView = {
		let stackView = UIStackView()
		stackView.axis = .horizontal
		stackView.spacing = 8
		stackView.alignment = .fill
		stackView.distribution = .fillProportionally
		stackView.translatesAutoresizingMaskIntoConstraints = false
		return stackView
	}()

	private init() {
		super.init(frame: .zero)

		self.backgroundColor = configuration.backgroundColor

		layer.borderColor = UIColor.systemGray3.cgColor
		layer.borderWidth = 0.5 / UIScreen.main.scale
		translatesAutoresizingMaskIntoConstraints = false

		addSubview(buttonsStackView)
		addSubview(doneButton)

		configureButtons(actions: [
			.bold, .italic, .underline, .strikethrough,
			.heading1, .heading2, .paragraph,
			.blockquote,
			.orderedList, .unorderedList,
		])

		setupConstraints()

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardFrameChanged),
			name: UIResponder.keyboardWillChangeFrameNotification,
			object: nil
		)
		// TODO: 监听选区变化以更新按钮状态，可以先预留
		// NotificationCenter.default.addObserver(self,
		//                                        selector: #selector(textViewDidChangeSelection(_:)),
		//                                        name: UITextView.textDidChangeSelectionNotification,
		//                                        object: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupConstraints() {
		NSLayoutConstraint.activate([
			buttonsStackView.leadingAnchor.constraint(
				equalTo: leadingAnchor,
				constant: 12
			),
			buttonsStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
			buttonsStackView.topAnchor.constraint(
				greaterThanOrEqualTo: topAnchor,
				constant: 4
			),
			buttonsStackView.bottomAnchor.constraint(
				lessThanOrEqualTo: bottomAnchor,
				constant: -4
			),

			doneButton.trailingAnchor.constraint(
				equalTo: trailingAnchor,
				constant: -12
			),
			doneButton.centerYAnchor.constraint(equalTo: centerYAnchor),
			buttonsStackView.trailingAnchor.constraint(
				lessThanOrEqualTo: doneButton.leadingAnchor,
				constant: -8
			),
		])
	}

	// 根据 RichTextAction 数组配置或更新按钮
	public func configureButtons(actions: [RichTextAction]) {
		actionButtons.forEach { $0.removeFromSuperview() }
		buttonsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
		actionButtons.removeAll()

		for action in actions {
			let button = RichTextActionButton(action: action)
			button.onTap = { [weak self] tappedAction in
				self?.handleRichTextAction(tappedAction)
			}
			actionButtons.append(button)
			buttonsStackView.addArrangedSubview(button)
		}
	}

	// 统一处理来自 RichTextActionButton 的动作
	private func handleRichTextAction(_ action: RichTextAction) {
		print("Toolbar: Action '\(action)' triggered.")
		// TODO: 将动作传递给 currentRichTextEditor
		// currentRichTextEditor?.perform(action) // 假设 RichTextEditor 有 perform(action:) 方法
		switch action {
		case .bold:
			print("bold")
		//			currentRichTextEditor?.toggleBold()
		case .italic:
			print("italic")
		//			currentRichTextEditor?.toggleItalic()
		// TODO: 实现斜体功能
		case .underline:
			print("underline")
		//			currentRichTextEditor?.toggleUnderline()
		// TODO: 实现下划线功能
		case .strikethrough:
			print("strikethrough")
		//			currentRichTextEditor?.toggleStrikethrough()
		// TODO: 实现删除线功能
		case .heading1:
			print("heading1")
		//			currentRichTextEditor?.applyHeading(level: 1)
		case .heading2:
			print("heading2")
		//			currentRichTextEditor?.applyHeading(level: 2)
		case .heading3:
			print("heading3")
		//			currentRichTextEditor?.applyHeading(level: 3)
		case .heading4:
			print("heading4")
		//			currentRichTextEditor?.applyHeading(level: 4)
		case .heading5:
			print("heading5")
		//			currentRichTextEditor?.applyHeading(level: 5)
		case .heading6:
			print("heading6")
		//			currentRichTextEditor?.applyHeading(level: 6)
		case .paragraph:
			print("paragraph")
		//			currentRichTextEditor?.applyParagraph()
		case .blockquote:
			print("blockquote")
		//			currentRichTextEditor?.toggleBlockquote()
		case .orderedList:
			print("orderedList")
		//			currentRichTextEditor?.toggleOrderedList()
		case .unorderedList:
			print("unorderedList")
		//			currentRichTextEditor?.toggleUnorderedList()

		// default:
		//     break
		}
	}

	func attach(to richTextEditor: RichTextEditor) {
		self.currentRichTextEditor = richTextEditor
		if let window = richTextEditor.window {
			show(view: window)
		} else {
			print(
				"Warning: RichTextEditor is not in a window at the moment of attaching toolbar."
			)
		}
		// TODO: 当编辑器附加时，需要根据编辑器的初始状态更新按钮的视觉状态
		// actionButtons.forEach { $0.updateVisualState(for: richTextEditor...) }
	}

	func detach() {
		self.currentRichTextEditor = nil
		if let currentSuperview = self.superview {
			self.toolbarTopConstraint?.constant = currentSuperview.bounds.height
			UIView.animate(
				withDuration: 0.25,
				animations: {
					currentSuperview.layoutIfNeeded()
				}
			) { _ in
				self.removeFromSuperview()
				self.toolbarTopConstraint?.isActive = false
				self.toolbarTopConstraint = nil
				self.toolbarHeightConstraint?.isActive = false
				self.toolbarHeightConstraint = nil
			}
		} else {
			self.removeFromSuperview()
			self.toolbarTopConstraint?.isActive = false
			self.toolbarTopConstraint = nil
			self.toolbarHeightConstraint?.isActive = false
			self.toolbarHeightConstraint = nil
		}
	}

	public func show(view: UIView) {
		if self.superview == view && toolbarTopConstraint != nil
			&& toolbarTopConstraint!.isActive
			&& toolbarTopConstraint!.isActive
		{
			return
		}

		if let oldConstraint = toolbarTopConstraint {
			oldConstraint.isActive = false
			toolbarTopConstraint = nil
		}
		if let oldHeightConstraint = toolbarHeightConstraint {
			oldHeightConstraint.isActive = false
			toolbarHeightConstraint = nil
		}
		self.removeFromSuperview()

		view.addSubview(self)

		let initialTopOffset = view.bounds.height
		toolbarTopConstraint = self.topAnchor.constraint(
			equalTo: view.topAnchor,
			constant: initialTopOffset
		)
		toolbarTopConstraint?.priority = .required

		toolbarHeightConstraint = self.heightAnchor.constraint(
			equalToConstant: configuration.height
		)

		NSLayoutConstraint.activate([
			leadingAnchor.constraint(equalTo: view.leadingAnchor),
			trailingAnchor.constraint(equalTo: view.trailingAnchor),
			//			heightAnchor.constraint(equalToConstant: configuration.height),
			toolbarHeightConstraint!,
			toolbarTopConstraint!,
		])

		//		self.frame = CGRect(
		//			x: 0,
		//			y: view.bounds.height,
		//			width: view.bounds.width,
		//			height: configuration.height
		//		)
		view.layoutIfNeeded()
	}

	public func setConfiguration(_ configuration: ToolbarConfiguration) {
		self.configuration = configuration
		self.backgroundColor = configuration.backgroundColor

		if let heightConstraint = self.toolbarHeightConstraint {
			heightConstraint.constant = configuration.height
		} else {
			//			self.heightAnchor.constraint(equalToConstant: configuration.height)
			//				.isActive = true
			let newHeightConstraint = self.heightAnchor.constraint(
				equalToConstant: configuration.height
			)
			newHeightConstraint.isActive = true
			self.toolbarHeightConstraint = newHeightConstraint
		}

		//		if let heightConstraint = self.constraints.first(where: {
		//			$0.firstAttribute == .height && $0.firstItem === self
		//		}) {
		//			heightConstraint.constant = configuration.height
		//		} else {
		//			self.heightAnchor.constraint(equalToConstant: configuration.height)
		//				.isActive = true
		//		}
		// self.layoutIfNeeded() // 可能需要强制重新布局
	}

	@objc private func doneTapped() {
		self.currentRichTextEditor?.endEditing(true)
	}

	@objc private func keyboardFrameChanged(_ notification: Notification) {
		print(
			"--- ⌨️ keyboardFrameChanged Notification: \(notification.name.rawValue) ---"
		)

		guard let userInfo = notification.userInfo,
			let superview = self.superview,
			let endFrameValue = userInfo[
				UIResponder.keyboardFrameEndUserInfoKey
			] as? NSValue,
			let duration = userInfo[
				UIResponder.keyboardAnimationDurationUserInfoKey
			] as? TimeInterval,
			let curveValue = userInfo[
				UIResponder.keyboardAnimationCurveUserInfoKey
			] as? UInt
		else {
			print(
				"Error: Missing userInfo or superview for keyboardFrameChanged."
			)
			return
		}

		let endFrame = endFrameValue.cgRectValue
		let animationCurve = UIView.AnimationOptions(rawValue: curveValue << 16)

		let keyboardFrameInSuperview = superview.convert(
			endFrame,
			from: UIScreen.main.coordinateSpace
		)

		// 打印原始键盘信息 (屏幕坐标系)
		print("Keyboard Screen Frame (endFrame): \(endFrame)")
		print("Toolbar Superview Frame: \(superview.frame)")
		print("Toolbar Superview Bounds: \(superview.bounds)")
		print("Toolbar Superview Safe Area Insets: \(superview.safeAreaInsets)")
		print("Keyboard Frame in Superview: \(keyboardFrameInSuperview)")
		print("Toolbar Configuration Height: \(self.configuration.height)")

		//		let keyboardYOnScreen = endFrame.origin.y
		//
		//		let keyboardFrameInSuperview = superview.convert(
		//			endFrame,
		//			from: UIScreen.main.coordinateSpace
		//		)

		//		let finalToolbarY: CGFloat
		let finalToolbarYConstant: CGFloat
		if keyboardFrameInSuperview.origin.y >= superview.bounds.height {
			print("hidden")
			//			finalToolbarY =
			//				superview.bounds.height - self.configuration.height
			//				- superview.safeAreaInsets.bottom
			//			print(
			//				"Calculated finalToolbarY (Keyboard Hidden): \(superview.bounds.height) - \(self.configuration.height) - \(superview.safeAreaInsets.bottom) = \(finalToolbarY)"
			//			)
			finalToolbarYConstant =
				superview.bounds.height - self.configuration.height
				- superview.safeAreaInsets.bottom
			print(
				"Calculated finalToolbarYConstant (Keyboard Hidden): \(finalToolbarYConstant)"
			)

		} else {
			print("showen")
			//			finalToolbarY =
			//				keyboardFrameInSuperview.origin.y - self.configuration.height
			//			print(
			//				"Calculated finalToolbarY (Keyboard Visible): \(keyboardFrameInSuperview.origin.y) - \(self.configuration.height) = \(finalToolbarY)"
			//			)
			finalToolbarYConstant =
				keyboardFrameInSuperview.origin.y - self.configuration.height
			print(
				"Calculated finalToolbarYConstant (Keyboard Visible): \(finalToolbarYConstant)"
			)

		}

		print(
			"Target Toolbar Top Constraint Constant: \(finalToolbarYConstant)"
		)
		if let topConstraint = self.toolbarTopConstraint {
			print(
				"Current Toolbar Top Constraint Constant before animation: \(topConstraint.constant)"
			)
			topConstraint.constant = finalToolbarYConstant
		} else {
			print("Error: toolbarTopConstraint is nil. Cannot update position.")
			return
		}

		UIView.animate(
			withDuration: duration,
			delay: 0,
			options: [animationCurve, .beginFromCurrentState],
			animations: {
				//				self.frame.origin.y = finalToolbarY
				superview.layoutIfNeeded()
			},
			completion: nil
		)
	}

	// 根据文本属性更新所有按钮的选中状态
	public func updateButtonStates(
		basedOn attributes: [NSAttributedString.Key: Any]
	) {
		var someBlockLevelButtonIsActive = false

		for button in actionButtons {
			var isActive = false
			let currentBlockType = attributes[.blockType] as? String
			let currentFont = attributes[.font] as? UIFont
			let currentMetadata = attributes[.metadata] as? [String: Any]

			switch button.action {
			// --- Inline Styles ---
			case .bold:
				if let font = currentFont {
					isActive = font.fontDescriptor.symbolicTraits.contains(
						.traitBold
					)
				}
			case .italic:
				if let font = currentFont {
					isActive = font.fontDescriptor.symbolicTraits.contains(
						.traitItalic
					)
				}
			case .underline:
				isActive =
					(attributes[.underlineStyle] as? NSNumber)?.intValue
					== NSUnderlineStyle.single.rawValue
			case .strikethrough:
				isActive =
					(attributes[.strikethroughStyle] as? NSNumber)?.intValue
					== NSUnderlineStyle.single.rawValue

			// --- Block Styles ---
			case .heading1:
				if currentBlockType == "heading",
					currentMetadata?["level"] as? Int == 1
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .heading2:
				if currentBlockType == "heading",
					currentMetadata?["level"] as? Int == 2
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .heading3:
				if currentBlockType == "heading",
					currentMetadata?["level"] as? Int == 3
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .heading4:
				if currentBlockType == "heading",
					currentMetadata?["level"] as? Int == 4
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .heading5:
				if currentBlockType == "heading",
					currentMetadata?["level"] as? Int == 5
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .heading6:
				if currentBlockType == "heading",
					currentMetadata?["level"] as? Int == 6
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .blockquote:
				if currentBlockType == "blockquote" {
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .orderedList:
				if currentBlockType == "list",
					currentMetadata?["ordered"] as? Bool == true
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .unorderedList:
				if currentBlockType == "list",
					currentMetadata?["ordered"] as? Bool == false
				{
					isActive = true
					someBlockLevelButtonIsActive = true
				}
			case .paragraph:
				if currentBlockType == "paragraph" {
					isActive = true
				} else if currentBlockType == nil
					&& !actionButtons.contains(where: {
						$0.isSelected && $0.action != .paragraph
							&& isBlockAction($0.action)
					})
				{
					isActive = true
				}
			}
			button.isSelected = isActive
		}
		if let paragraphButton = actionButtons.first(where: {
			$0.action == .paragraph
		}) {
			// Check if any *other* block-level button ended up being selected
			let anotherBlockButtonIsSelected = actionButtons.contains { btn in
				btn.isSelected && btn.action != .paragraph
					&& isBlockAction(btn.action)
			}

			if anotherBlockButtonIsSelected {
				paragraphButton.isSelected = false
			} else {
				// If no other block button is selected, then the paragraph button's state
				// is determined by whether the current block is actually a paragraph (or nil type).
				let currentBlockType = attributes[.blockType] as? String
				paragraphButton.isSelected =
					(currentBlockType == "paragraph" || currentBlockType == nil)
			}
		}
	}

	private func isBlockAction(_ action: RichTextAction) -> Bool {
		switch action {
		case .heading1, .heading2, /* .heading3, etc. */ .blockquote,
			.orderedList, .unorderedList:
			return true
		default:
			return false
		}
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

// 扩展 UIFont 以方便检查 traits (可选，但推荐)
extension UIFont {
	func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
		guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
			return self
		}
		return UIFont(descriptor: descriptor, size: pointSize)  // 保留原字号
	}

	func withoutTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
		let currentTraits = fontDescriptor.symbolicTraits
		guard
			let descriptor = fontDescriptor.withSymbolicTraits(
				currentTraits.subtracting(traits)
			)
		else {
			return self
		}
		return UIFont(descriptor: descriptor, size: pointSize)
	}
}
