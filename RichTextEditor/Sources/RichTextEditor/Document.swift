//
//  Document.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit

//struct BlockInfo {
//    let blockID: UUID
//    let blockType: String
//    let children: [BlockInfo]
//
//    init(blockID: UUID, blockType: String, children: [BlockInfo] = []) {
//        self.blockID = blockID
//        self.blockType = blockType
//        self.children = children
//    }
//}
//
//struct Metadata {
//    var level: Int?
//}

extension NSAttributedString.Key {
    static let blockID = NSAttributedString.Key(rawValue: "blockID")
    static let blockType = NSAttributedString.Key(rawValue: "blockType")
    static let metadata = NSAttributedString.Key(rawValue: "metadata")
}

class Document {
    var blocks: [IdentifiedBlock]
    
    init(blocks: [IdentifiedBlock] = []) {
        self.blocks = blocks
    }
    
    func toAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in blocks {
            let attributedString = block.block.toAttributedString()
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
            mutableAttributedString.addAttribute(.blockType, value: block.block.getType(), range: NSRange(location: 0, length: mutableAttributedString.length))
            mutableAttributedString.addAttribute(.blockID, value: block.id, range: NSRange(location: 0, length: mutableAttributedString.length))
            result.append(mutableAttributedString)
        }
        return result
    }
}

class IdentifiedBlock {
    let id: UUID
    var block: Block
    
    init(block: Block) {
        self.id = UUID()
        self.block = block
    }
    
    init(id: UUID, block: Block) {
        self.id = id
        self.block = block
    }
}

enum Block {
    case paragraph(content: [InlineTextFragment])
    case heading(level: Int, content: [InlineTextFragment])
    case blockquote(content: BlockquoteContent)
    case list(content: ListContent)
    
    func getType () -> String {
        switch self {
        case .paragraph:
            return "paragraph"
        case .heading:
            return "heading"
        case .blockquote:
            return "blockquote"
        case .list:
            return "list"
        }
    }
    
    func toAttributedString(level: Int = 0) -> NSAttributedString {
        let result = NSMutableAttributedString()
        switch self {
        case .paragraph(let content):
            for fragment in content {
                let attributedString = fragment.toAttributedString()
                result.append(attributedString)
            }
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
            let headingMetadata: [String: Any] = ["level": level]
            for fragment in content {
                let attributedString = fragment.toAttributedString()
                var attributes = attributedString.attributes(at: 0, effectiveRange: nil)
                attributes[NSAttributedString.Key.font] = font
                attributes[NSAttributedString.Key.metadata] = headingMetadata
                let attributedFragment = NSAttributedString(string: fragment.text, attributes: attributes)
                result.append(attributedFragment)
            }
        case .blockquote(let content):
            result.append(content.toAttributedString(parentID: UUID()))
        case .list(let content):
            result.append(content.toAttributedString(parentID: UUID()))
        }
        return result
    }
}

enum BlockquoteItem {
    case text(content: [InlineTextFragment])
    case list(content: BlockquoteContent)
}

class BlockquoteContent {
    var items: [BlockquoteItem]
    var ordered: Bool
    
    init(items: [BlockquoteItem], ordered: Bool = false) {
        self.items = items
        self.ordered = ordered
    }
    
    func toAttributedString(level: Int = 0, parentID: UUID) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for item in items {
            let str = NSMutableAttributedString()
            switch item {
            case .text(let content):
                let paragraphStyle = BlockquoteContent.getParagraphStyle(level: level)
                
                str.append(NSAttributedString(string: "\u{200B}"))
                for fragment in content {
                    str.append(fragment.toAttributedString())
                }
                if level != 0 {
                    let metadata: [String: Any] = [
                        "level": level,
                        "ordered": ordered,
                        "id": UUID(),
                        "parentID": parentID,
                    ]
                    str.addAttribute(.metadata, value: metadata, range: NSRange(location: 0, length: str.length))
                }
                str.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: str.length))
            case .list(let content):
                str.append(content.toAttributedString(level: level + 1, parentID: UUID()))
            }
            result.append(str)
        }
        return result
    }
    
    static func getParagraphStyle(level: Int) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = 24 + CGFloat(level * 24)
        paragraphStyle.firstLineHeadIndent = 24 + CGFloat(level * 24)
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 4
        return paragraphStyle
    }
}

enum ListItem {
    case text(content: [InlineTextFragment])
    case list(content: ListContent)
}

class ListContent {
    var items: [ListItem]
    var ordered: Bool
    
    init(items: [ListItem], ordered: Bool = false) {
        self.items = items
        self.ordered = ordered
    }
    
    func toAttributedString(level: Int = 0, parentID: UUID) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for item in items {
            let str = NSMutableAttributedString()
            switch item {
            case .text(let content):
                let paragraphStyle = ListContent.getParagraphStyle(level: level)
                
                str.append(NSAttributedString(string: "\u{200B}"))
                for fragment in content {
                    str.append(fragment.toAttributedString())
                }
                let metadata: [String: Any] = [
                    "level": level,
                    "ordered": ordered,
                    "id": UUID(),
                    "parentID": parentID,
                ]
                str.addAttribute(.metadata, value: metadata, range: NSRange(location: 0, length: str.length))
                str.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: str.length))
            case .list(let content):
                str.append(content.toAttributedString(level: level + 1, parentID: UUID()))
            }
            result.append(str)
        }
        return result
    }
    
    static func getParagraphStyle(level: Int) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.headIndent = CGFloat((level + 1) * 24)
        paragraphStyle.firstLineHeadIndent = CGFloat((level + 1) * 24)
        paragraphStyle.alignment = .left
        return paragraphStyle
    }
}

class InlineTextFragment {
    var text: String
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var textColor: UIColor?
    
    init(text: String, isBold: Bool = false, isItalic: Bool = false, isUnderline: Bool = false, textColor: UIColor? = nil) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.textColor = textColor
    }
    
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
            .underlineStyle: isUnderline ? NSUnderlineStyle.single.rawValue : 0,
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}
