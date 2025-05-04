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

extension ListItem {
    func toAttributedString(level: Int) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in content {
            let attributedString = block.toAttributedString(level: level)
            result.append(attributedString)
        }
        return result
    }
}

extension Block {
    func toAttributedString(level: Int = 0) -> NSAttributedString {
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
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = CGFloat((level + 1) * 24)
            paragraphStyle.firstLineHeadIndent = CGFloat((level + 1) * 24)
            paragraphStyle.alignment = .left
            let result = NSMutableAttributedString()
            for item in items {
                let attributedString = NSMutableAttributedString(attributedString: item.toAttributedString(level: level + 1))
                let existingLevel = attributedString.attribute(NSAttributedString.Key("listLevel"), at: 0, effectiveRange: nil) as? Int
                if existingLevel == nil {
                    attributedString.addAttribute(NSAttributedString.Key("listLevel"), value: level, range: NSRange(location: 0, length: attributedString.length))
                    attributedString.addAttribute(NSAttributedString.Key("listStyle"), value: getUnorderedListStyle(level: level), range: NSRange(location: 0, length: attributedString.length))
                    attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
                }
                result.append(attributedString)
                result.append(NSAttributedString(string: "\n"))
            }
            return result
        case .orderedList(let items):
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = CGFloat((level + 1) * 24)
            paragraphStyle.firstLineHeadIndent = CGFloat((level + 1) * 24)
            paragraphStyle.alignment = .left
            let result = NSMutableAttributedString()
            for (index, item) in items.enumerated() {
                let attributedString = NSMutableAttributedString(attributedString: item.toAttributedString(level: level + 1))
                // check if attribute is already exists
                let existingLevel = attributedString.attribute(NSAttributedString.Key("listLevel"), at: 0, effectiveRange: nil) as? Int
                if existingLevel == nil {
                    attributedString.addAttribute(NSAttributedString.Key("listLevel"), value: level, range: NSRange(location: 0, length: attributedString.length))
                    attributedString.addAttribute(NSAttributedString.Key("listStyle"), value: getOrderedListStyle(level: level, index: index), range: NSRange(location: 0, length: attributedString.length))
                    attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedString.length))
                }
                result.append(attributedString)
                result.append(NSAttributedString(string: "\n"))
            }
            return result
        }
        // TODO: Combine unordered and ordered list and use a common Key
    }
    
    private func getUnorderedListStyle(level: Int) -> String {
        switch level % 3 {
        case 0:
            return "• "
        case 1:
            return "◦ "
        case 2:
            return "▪ "
        default:
            return ""
        }
    }
    
    private func getOrderedListStyle(level: Int, index: Int) -> String {
        switch level % 3 {
        case 0:
            return "\(index + 1). "
        case 1:
            let letters = "abcdefghijklmnopqrstuvwxyz"
            let letterIndex = index % letters.count
            let letter = letters[letters.index(letters.startIndex, offsetBy: letterIndex)]
            return "\(letter). "
        case 2:
            let romanNumerals: [(Int, String)] = [
                (1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
                (100, "c"), (90, "xc"), (50, "l"), (40, "xl"),
                (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")
            ]
            
            var result = ""
            var number = index + 1
            for (value, numeral) in romanNumerals {
                while number >= value {
                    result += numeral
                    number -= value
                }
            }
            return "\(result). "
        default:
            return ""
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
