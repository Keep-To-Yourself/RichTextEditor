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

	// 完成按钮
	private lazy var doneButton: UIButton = {
		let button = UIButton(type: .system)
		button.setTitle("完成", for: .normal)
		button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
		button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		button.setContentCompressionResistancePriority(.required, for: .horizontal)
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
		
		configureButtons(actions: [.bold, .italic, .underline, .strikethrough])

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
			buttonsStackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 4), // 允许一些内边距
			buttonsStackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),// 允许一些内边距
			// buttonsStackView 的高度由其内容决定，或者由其在 centerYAnchor 上的对齐以及 Toolbar 高度决定

			doneButton.trailingAnchor.constraint(
				equalTo: trailingAnchor,
				constant: -12
			),
			doneButton.centerYAnchor.constraint(equalTo: centerYAnchor),
			// 确保 doneButton 和 buttonsStackView 之间有间隔，并且 stackView 不会与 doneButton 重叠
			buttonsStackView.trailingAnchor.constraint(
				lessThanOrEqualTo: doneButton.leadingAnchor,
				constant: -8 // 至少8点的间隔
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
			print("bold");
//			currentRichTextEditor?.toggleBold()
		case .italic:
			print("italic");
//			currentRichTextEditor?.toggleItalic()
			// TODO: 实现斜体功能
		case .underline:
			print("underline");
//			currentRichTextEditor?.toggleUnderline()
			// TODO: 实现下划线功能
		case .strikethrough:
			print("strikethrough");
//			currentRichTextEditor?.toggleStrikethrough()
			// TODO: 实现删除线功能
		// default:
		//     break
		}
	}

	func attach(to richTextEditor: RichTextEditor) {
		self.currentRichTextEditor = richTextEditor
		// TODO: 当编辑器附加时，需要根据编辑器的初始状态更新按钮的视觉状态
		// actionButtons.forEach { $0.updateVisualState(for: richTextEditor...) }
	}

	func detach() {
		self.currentRichTextEditor = nil
	}

	public func show(view: UIView) {
		if self.superview == view { return }
		self.removeFromSuperview()
		
		view.addSubview(self)
		
		NSLayoutConstraint.activate([
			leadingAnchor.constraint(equalTo: view.leadingAnchor),
			trailingAnchor.constraint(equalTo: view.trailingAnchor),
			heightAnchor.constraint(equalToConstant: configuration.height),
		])
		
		self.frame = CGRect(x: 0, y: view.bounds.height, width: view.bounds.width, height: configuration.height)
	}

	public func setConfiguration(_ configuration: ToolbarConfiguration) {
		self.configuration = configuration
		self.backgroundColor = configuration.backgroundColor
		
		if let heightConstraint = self.constraints.first(where: { $0.firstAttribute == .height && $0.firstItem === self }) {
			heightConstraint.constant = configuration.height
		} else {
			self.heightAnchor.constraint(equalToConstant: configuration.height).isActive = true
		}
		// self.layoutIfNeeded() // 可能需要强制重新布局
	}

	@objc private func doneTapped() {
		self.currentRichTextEditor?.endEditing(true)
	}

	@objc private func keyboardFrameChanged(_ notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let superview = self.superview,
			  let endFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
			  let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
			  let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
		else {
			return
		}

		let endFrame = endFrameValue.cgRectValue
		let animationCurve = UIView.AnimationOptions(rawValue: curveValue << 16)
		
		let keyboardYOnScreen = endFrame.origin.y
		
		let keyboardFrameInSuperview = superview.convert(endFrame, from: UIScreen.main.coordinateSpace)
		
		let finalToolbarY: CGFloat
		if keyboardFrameInSuperview.origin.y >= superview.bounds.height {
			finalToolbarY = superview.bounds.height - self.configuration.height - superview.safeAreaInsets.bottom
		} else {
			finalToolbarY = keyboardFrameInSuperview.origin.y - self.configuration.height
		}
		
		UIView.animate(withDuration: duration, delay: 0, options: [animationCurve, .beginFromCurrentState], animations: {
			self.frame.origin.y = finalToolbarY
		}, completion: nil)
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}
