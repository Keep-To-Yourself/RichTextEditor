//
//  ButtonAction.swift
//  RichTextEditor
//
//  Created by 易汉斌 on 2025/5/15.
//

import UIKit

public enum RichTextAction: CaseIterable {
	case bold
	case italic
	case underline
	case strikethrough
	case heading1
	case heading2
	case heading3
	case heading4
	case heading5
	case heading6
	case paragraph
	case blockquote
	case orderedList
	case unorderedList

	public func getDefaultButtonDisplayContent() -> (
		image: UIImage?, title: String?
	) {
		if #available(iOS 13.0, *) {
			switch self {
			case .bold:
				return (UIImage(systemName: "bold"), nil)
			case .italic:
				return (UIImage(systemName: "italic"), nil)
			case .underline:
				return (UIImage(systemName: "underline"), nil)
			case .strikethrough:
				return (UIImage(systemName: "strikethrough"), nil)
			case .heading1:
				return (UIImage(systemName: "h1.square.fill"), "H1")
			case .heading2:
				return (UIImage(systemName: "h2.square.fill"), "H2")
			case .heading3:
				return (UIImage(systemName: "h3.square.fill"), "H3")
			case .heading4:
				return (UIImage(systemName: "h4.square.fill"), "H4")
			case .heading5:
				return (UIImage(systemName: "h5.square.fill"), "H5")
			case .heading6:
				return (UIImage(systemName: "h6.square.fill"), "H6")
			case .paragraph:
				return (UIImage(systemName: "paragraphsign"), "P")
			case .blockquote:
				return (UIImage(systemName: "text.quote"), nil)
			case .orderedList:
				return (UIImage(systemName: "list.number"), nil)
			case .unorderedList:
				return (UIImage(systemName: "list.bullet"), nil)
			}
		} else {
			// iOS 13 以下的回退方案 (纯文字)
			switch self {
			case .bold: return (nil, "B")
			case .italic: return (nil, "I")
			case .underline: return (nil, "U")
			case .strikethrough: return (nil, "S")
			case .heading1: return (nil, "H1")
			case .heading2: return (nil, "H2")
			case .heading3: return (nil, "H3")
			case .heading4: return (nil, "H4")
			case .heading5: return (nil, "H5")
			case .heading6: return (nil, "H6")
			case .paragraph: return (nil, "P")
			case .blockquote: return (nil, "引用")
			case .orderedList: return (nil, "有序")
			case .unorderedList: return (nil, "无序")
			}
		}
	}
}
