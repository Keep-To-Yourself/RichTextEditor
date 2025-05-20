//
//  Document.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/30.
//

import UIKit
import Collections

extension NSAttributedString.Key {
    static let blockID = NSAttributedString.Key(rawValue: "blockID")
    static let blockType = NSAttributedString.Key(rawValue: "blockType")
    static let metadata = NSAttributedString.Key(rawValue: "metadata")
}

public class Document: Codable {
    var blocks: OrderedDictionary<UUID, Block>
    
    private var blockquotes: [UUID: BlockquoteContent] = [:]
    private var lists: [UUID: ListContent] = [:]
    
    enum CodingKeys: String, CodingKey {
        case blocks
    }
    
    init(blocks: OrderedDictionary<UUID, Block> = [:]) {
        self.blocks = blocks
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var blocksDecoder = try container.superDecoder(forKey: .blocks)
        self.blocks = try OrderedDictionary<UUID, Block>(from: blocksDecoder)
        
        func processNestedBlockquotes(_ content: BlockquoteContent) {
            self.addBlockquote(content)
            for item in content.items {
                if case .list(let nestedContent) = item {
                    processNestedBlockquotes(nestedContent)
                }
            }
        }
        
        func processNestedLists(_ content: ListContent) {
            self.addList(content)
            for item in content.items {
                if case .list(let nestedContent) = item {
                    processNestedLists(nestedContent)
                }
            }
        }
        
        for (id, block) in blocks {
            switch block {
            case .blockquote(let content):
                processNestedBlockquotes(content)
            case .list(let content):
                processNestedLists(content)
            default:
                continue
            }
        }
    }
    
    func addList(_ list: ListContent) {
        lists[list.id] = list
    }
    
    func getList(_ id: UUID) -> ListContent? {
        return lists[id]
    }
    
    func addBlockquote(_ blockquote: BlockquoteContent) {
        blockquotes[blockquote.id] = blockquote
    }
    
    func getBlockquote(_ id: UUID) -> BlockquoteContent? {
        return blockquotes[id]
    }
    
    public func toAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (id, block) in blocks {
            let attributedString = block.toAttributedString(document: self)
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
            mutableAttributedString.addAttribute(.blockType, value: block.getType(), range: NSRange(location: 0, length: mutableAttributedString.length))
            mutableAttributedString.addAttribute(.blockID, value: id, range: NSRange(location: 0, length: mutableAttributedString.length))
            result.append(mutableAttributedString)
        }
        return result
    }
}

enum Block: Codable {
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
    
    func toAttributedString(document: Document) -> NSAttributedString {
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
            result.append(content.toAttributedString(document: document))
        case .list(let content):
            result.append(content.toAttributedString(document: document))
        }
        return result
    }
}

enum BlockquoteItem: Codable {
    case text(content: [InlineTextFragment])
    case list(content: BlockquoteContent)
}

class BlockquoteContent: Codable {
    let id: UUID
    let parentID: UUID?
    var items: [BlockquoteItem]
    var ordered: Bool
    
    init(document: Document, parentID: UUID?, items: [BlockquoteItem], ordered: Bool = false) {
        self.id = UUID()
        self.parentID = parentID
        self.items = items
        self.ordered = ordered
        document.addBlockquote(self)
    }
    
    init(document: Document, id: UUID, parentID: UUID?, items: [BlockquoteItem], ordered: Bool = false) {
        self.id = id
        self.parentID = parentID
        self.items = items
        self.ordered = ordered
        document.addBlockquote(self)
    }
    
    func toAttributedString(document: Document, level: Int = 0) -> NSAttributedString {
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
                        "ordered": self.ordered,
                        "id": UUID(),
                        "parentID": self.id,
                    ]
                    str.addAttribute(.metadata, value: metadata, range: NSRange(location: 0, length: str.length))
                }
                str.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: str.length))
            case .list(let content):
                str.append(content.toAttributedString(document: document, level: level + 1))
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

enum ListItem: Codable {
    case text(content: [InlineTextFragment])
    case list(content: ListContent)
}

class ListContent: Codable {
    let id: UUID
    let parentID: UUID?
    var items: [ListItem]
    var ordered: Bool
    
    init(document: Document, parentID: UUID?, items: [ListItem], ordered: Bool = false) {
        self.id = UUID()
        self.parentID = parentID
        self.items = items
        self.ordered = ordered
        document.addList(self)
    }
    
    init(document: Document, id: UUID, parentID: UUID?, items: [ListItem], ordered: Bool = false) {
        self.id = id
        self.parentID = parentID
        self.items = items
        self.ordered = ordered
        document.addList(self)
    }
    
    func toAttributedString(document: Document, level: Int = 0) -> NSAttributedString {
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
                    "ordered": self.ordered,
                    "id": UUID(),
                    "parentID": self.id,
                ]
                str.addAttribute(.metadata, value: metadata, range: NSRange(location: 0, length: str.length))
                str.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: str.length))
            case .list(let content):
                str.append(content.toAttributedString(document: document, level: level + 1))
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

class InlineTextFragment: Codable {
    var text: String
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var textColor: UIColor?
    
    
    enum CodingKeys: String, CodingKey {
        case text, isBold, isItalic, isUnderline
        case red, green, blue, alpha
    }
    
    init(text: String, isBold: Bool = false, isItalic: Bool = false, isUnderline: Bool = false, textColor: UIColor? = nil) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.textColor = textColor
    }
    
    // MARK: - 编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(isBold, forKey: .isBold)
        try container.encode(isItalic, forKey: .isItalic)
        try container.encode(isUnderline, forKey: .isUnderline)
        
        if let color = textColor {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            try container.encode(Double(r), forKey: .red)
            try container.encode(Double(g), forKey: .green)
            try container.encode(Double(b), forKey: .blue)
            try container.encode(Double(a), forKey: .alpha)
        }
    }
    
    // MARK: - 解码
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        isBold = try container.decode(Bool.self, forKey: .isBold)
        isItalic = try container.decode(Bool.self, forKey: .isItalic)
        isUnderline = try container.decode(Bool.self, forKey: .isUnderline)
        
        if let r = try? container.decode(Double.self, forKey: .red),
           let g = try? container.decode(Double.self, forKey: .green),
           let b = try? container.decode(Double.self, forKey: .blue),
           let a = try? container.decode(Double.self, forKey: .alpha) {
            textColor = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        } else {
            textColor = nil
        }
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
