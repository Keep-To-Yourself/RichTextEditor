//
//  ButtonAction.swift
//  RichTextEditor
//
//  Created by 易汉斌 on 2025/5/15.
//

import UIKit

enum RichTextAction: CaseIterable {
	case bold
	case italic
	case underline
	case strikethrough

	public func getDefaultButtonDisplayContent() -> (image: UIImage?, title: String?) {
		switch self {
		case .bold:
			// iOS 13+，使用 SFSymbols
			if #available(iOS 13.0, *) {
				return (UIImage(systemName: "bold"), nil)
			} else {
				return (nil, "B")
			}
		case .italic:
			if #available(iOS 13.0, *) {
				return (UIImage(systemName: "italic"), nil)
			} else {
				return (nil, "I")
			}
		case .underline:
			if #available(iOS 13.0, *) {
				return (UIImage(systemName: "underline"), nil)
			} else {
				return (nil, "U")
			}
		case .strikethrough:
			if #available(iOS 13.0, *) {
				return (UIImage(systemName: "strikethrough"), nil)
			} else {
				return (nil, "S")
			}
		}
	}
}
