//
//  RichTextEditor.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/29.
//

import UIKit

public class RichTextEditor: UIView {

	private var textView: TextEditor!
	internal var configuration: RichTextEditorConfiguration
	public var onFocusChanged: ((Bool) -> Void)?

	public init(configuration: RichTextEditorConfiguration) {
		self.configuration = configuration
		super.init(frame: .zero)

		textView = TextEditor(self)
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
