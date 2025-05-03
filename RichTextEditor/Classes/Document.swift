//
//  Document.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

struct Document {
    var blocks: [Block]
}

enum Block {
    case paragraph([InlineTextFragment])
    case heading(level: Int, content: [InlineTextFragment])
    case blockquote([Block])
    case unorderedList([ListItem])
    case orderedList([ListItem])
}

struct ListItem {
    var content: [Block]
}

struct InlineTextFragment {
    var text: String
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var textColor: UIColor?
}

extension InlineTextFragment {
    func toAttributedString() -> NSAttributedString {
        var traits: UIFontDescriptor.SymbolicTraits = []

        if self.isBold {
            traits.insert(.traitBold)
        }
        if self.isItalic {
            traits.insert(.traitItalic)
        }
        var font = UIFont.systemFont(ofSize: 16)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: descriptor, size: 16)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor ?? UIColor.black,
            .underlineStyle: isUnderline ? NSUnderlineStyle.styleSingle.rawValue : 0,
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}
extension Block {
    func toAttributedString() -> NSAttributedString {
        switch self {
        case .paragraph(let fragments):
            let result = NSMutableAttributedString()
            for fragment in fragments {
                let attributedString = fragment.toAttributedString()
                result.append(attributedString)
            }
            return result
        case .heading(let level, let content):
            let fontSize: CGFloat = {
                switch level {
                    // TODO: Use rem instead of fixed size
                case 1: return 32
                case 2: return 24
                case 3: return 18.72
                case 4: return 16
                case 5: return 13.28
                case 6: return 10.72;
                default: return 16
                }
            }()
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let result = NSMutableAttributedString()
            for fragment in content {
                let attributedString = fragment.toAttributedString()
                var attributes = attributedString.attributes(at: 0, effectiveRange: nil)
                attributes[NSAttributedString.Key.font] = font
                let attributedFragment = NSAttributedString(string: fragment.text, attributes: attributes)
                result.append(attributedFragment)
            }
            return result
        case .blockquote(let blocks):
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 24
            paragraphStyle.firstLineHeadIndent = 24
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = 4
            let result = NSMutableAttributedString()
            for block in blocks {
                let attributedString = block.toAttributedString()
                var attributes = attributedString.attributes(at: 0, effectiveRange: nil)
                attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
                let attributedFragment = NSAttributedString(string: attributedString.string, attributes: attributes)
                result.append(attributedFragment)
            }
            result.addAttribute(NSAttributedString.Key("blockquote"), value: true, range: NSRange(location: 0, length: result.length))
            return result
        case .unorderedList(let items):
            // TODO: Implement
            return NSAttributedString(string: "UL Test")
        case .orderedList(let items):
            return NSAttributedString(string: "OL Test")
        }
    }
}

extension Document {
    func toAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in blocks {
            let attributedString = block.toAttributedString()
            result.append(attributedString)
            result.append(NSAttributedString(string: "\n"))
        }
        return result
    }
}
