//
//  TextStorage.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/5/5.
//

import UIKit

class DocumentTextStorage: NSTextStorage {
    private let backingStore = NSMutableAttributedString()
    private var document: Document
    
    init(document: Document) {
        self.document = document
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var string: String {
        return backingStore.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        edited([.editedCharacters, .editedAttributes], range: range, changeInLength: str.utf16.count - range.length)
        endEditing()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backingStore.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    func apply() {
        beginEditing()
        let originalLength = backingStore.length
        let newAttrString = document.toAttributedString()
        backingStore.setAttributedString(newAttrString)
        let changeInLength = newAttrString.length - originalLength
        edited(
            [.editedCharacters, .editedAttributes],
            range: NSRange(location: 0, length: originalLength),
            changeInLength: changeInLength
        )
        endEditing()
    }
    
    override public func processEditing() {
        super.processEditing()
        
        // range: {位置，长度}
        let range = self.editedRange
        // delta: 变化的长度
        let delta = self.changeInLength
        print("range: \(range), delta: \(delta)")
        
        guard range.location != NSNotFound && range.location > 0 else { return }
        // TODO: Create a new block (?) when range.location == 0
        
        var blockID: UUID?
        var blockType: String?
        var metadata: [String: Any]?
        var blockRange = NSRange(location: NSNotFound, length: 0)
        if range.location < length {
            blockID = attribute(.blockID, at: range.location - 1, effectiveRange: &blockRange) as? UUID
            blockType = attribute(.blockType, at: range.location - 1, effectiveRange: nil) as? String
            metadata = attribute(.metadata, at: range.location - 1, effectiveRange: nil) as? [String: Any]
        }
        guard let blockID = blockID else { return }
        guard let blockType = blockType else { return }
        
        if delta >= 0 {
            // 插入或替换文本
            print("block range: \(blockRange)")
            let blockString = attributedSubstring(from: blockRange)
            print("Block ID: \(blockID), Content: \(blockString.string)")
            
            let addedString = attributedSubstring(from: range)
            print("Added String: \(addedString.string)")
            
            // apply attributes to the new content
            
            if addedString.string == "\n" {
                print("New Line")
                // TODO: Process newline
            }else{
                addAttributes([
                    .blockID: blockID,
                    .blockType: blockType,
                ], range: editedRange)
                if metadata != nil {
                    addAttributes([.metadata: metadata!], range: editedRange)
                }
            }
            
        } else {
            // 删除文本
        }
        
        updateDocumentBlock(with: blockID)
    }
    
    private func updateDocumentBlock(with blockID: UUID) {
        guard let block = document.blocks.first(where: { $0.id == blockID }) else { return }
        
        // TODO: Implement the logic to update the document block
        
        // get the current text by attribute blockID
        enumerateAttribute(.blockID, in: NSRange(location: 0, length: length), options: []) { (value, range, stop) in
            if let blockID = value as? UUID, blockID == block.id {
                let text = attributedSubstring(from: range)
                // print("Block ID: \(blockID), All Content: \(text.string)")
            }
        }
        
        switch block.block {
        case .paragraph:
            break
        case .heading(let level, let content):
            break
        case .blockquote(let blocks):
            break
        case .list(let items):
            break
        }
    }
}
