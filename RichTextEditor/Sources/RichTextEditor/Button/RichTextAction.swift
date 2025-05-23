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
    case increaseIndent
    case decreaseIndent
    
    public func getDefaultButtonDisplayContent() -> (image: UIImage?, title: String?) {
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
        case .increaseIndent:
            return (UIImage(systemName: "increase.indent"), nil)
        case .decreaseIndent:
            return (UIImage(systemName: "decrease.indent"), nil)
        }
    }
}
