import Foundation
import UIKit

// 定义通知名称
extension Notification.Name {
    static let noteDataChanged = Notification.Name("noteDataChanged")
}

struct Note: Codable {
    let id: UUID
    var title: String
    var content: Data // 存储NSAttributedString
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String, content: NSAttributedString, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = try! NSKeyedArchiver.archivedData(withRootObject: content, requiringSecureCoding: false)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func getAttributedContent() -> NSAttributedString {
        do {
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(content) as! NSAttributedString
        } catch {
            print("Error unarchiving content: \(error)")
            return NSAttributedString(string: "")
        }
    }
    
    mutating func updateContent(_ content: NSAttributedString) {
        do {
            self.content = try NSKeyedArchiver.archivedData(withRootObject: content, requiringSecureCoding: false)
            self.updatedAt = Date()
        } catch {
            print("Error archiving content: \(error)")
        }
    }
}

class NoteStore {
    static let shared = NoteStore()
    
    private let fileManager = FileManager.default
    private var notesDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let notesDirectory = documentsDirectory.appendingPathComponent("notes")
        
        // 确保目录存在
        if !fileManager.fileExists(atPath: notesDirectory.path) {
            do {
                try fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true, attributes: nil)
                print("创建笔记目录: \(notesDirectory.path)")
            } catch {
                print("创建笔记目录失败: \(error)")
            }
        }
        
        return notesDirectory
    }
    
    private var notesIndexFile: URL {
        return notesDirectory.appendingPathComponent("index.json")
    }
    
    private init() {
        print("NoteStore初始化，笔记目录: \(notesDirectory.path)")
        
        // 加载索引文件，如果不存在则创建
        if !fileManager.fileExists(atPath: notesIndexFile.path) {
            print("笔记索引文件不存在，创建新索引")
            saveNotesIndex([])
        } else {
            print("笔记索引文件存在: \(notesIndexFile.path)")
        }
    }
    
    // 笔记索引，只存储笔记的元数据
    private func loadNotesIndex() -> [Note] {
        do {
            let data = try Data(contentsOf: notesIndexFile)
            let notes = try JSONDecoder().decode([Note].self, from: data)
            print("成功加载笔记索引，包含\(notes.count)条笔记")
            return notes
        } catch {
            print("加载笔记索引失败: \(error)")
            return []
        }
    }
    
    private func saveNotesIndex(_ notes: [Note]) {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: notesIndexFile, options: .atomic)
            print("成功保存笔记索引，包含\(notes.count)条笔记")
        } catch {
            print("保存笔记索引失败: \(error)")
        }
    }
    
    // 获取笔记内容文件的URL
    private func noteContentURL(for id: UUID) -> URL {
        return notesDirectory.appendingPathComponent("\(id.uuidString).content")
    }
    
    // 保存笔记内容到单独的文件
    private func saveNoteContent(_ note: Note) {
        let contentURL = noteContentURL(for: note.id)
        do {
            try note.content.write(to: contentURL)
            print("成功保存笔记内容: \(contentURL.path)")
        } catch {
            print("保存笔记内容失败: \(error)")
        }
    }
    
    // 加载笔记内容
    private func loadNoteContent(for id: UUID) -> Data? {
        let contentURL = noteContentURL(for: id)
        do {
            let contentData = try Data(contentsOf: contentURL)
            print("成功加载笔记内容: \(contentURL.path)")
            return contentData
        } catch {
            print("加载笔记内容失败: \(error)")
            return nil
        }
    }
    
    var notes: [Note] {
        return loadNotesIndex()
    }
    
    func addNote(_ note: Note) {
        var currentNotes = loadNotesIndex()
        currentNotes.append(note)
        saveNotesIndex(currentNotes)
        saveNoteContent(note)
        
        print("笔记已保存: ID=\(note.id), 标题=\(note.title)")
        
        // 发送数据变化通知
        NotificationCenter.default.post(name: .noteDataChanged, object: nil)
    }
    
    func updateNote(_ note: Note) {
        var currentNotes = loadNotesIndex()
        if let index = currentNotes.firstIndex(where: { $0.id == note.id }) {
            currentNotes[index] = note
            saveNotesIndex(currentNotes)
            saveNoteContent(note)
            
            print("笔记已更新: ID=\(note.id), 标题=\(note.title)")
            
            // 发送数据变化通知
            NotificationCenter.default.post(name: .noteDataChanged, object: nil)
        } else {
            print("更新笔记失败：未找到ID=\(note.id)的笔记")
        }
    }
    
    func deleteNote(withId id: UUID) {
        var currentNotes = loadNotesIndex()
        currentNotes.removeAll { $0.id == id }
        saveNotesIndex(currentNotes)
        
        // 删除笔记内容文件
        let contentURL = noteContentURL(for: id)
        do {
            try fileManager.removeItem(at: contentURL)
            print("成功删除笔记内容文件: \(contentURL.path)")
        } catch {
            print("删除笔记内容文件失败: \(error)")
        }
        
        print("笔记已删除: ID=\(id)")
        
        // 发送数据变化通知
        NotificationCenter.default.post(name: .noteDataChanged, object: nil)
    }
    
    func getNote(byId id: UUID) -> Note? {
        guard let metaNote = notes.first(where: { $0.id == id }) else {
            print("未找到ID=\(id)的笔记")
            return nil
        }
        
        // 从文件加载笔记内容
        if let contentData = loadNoteContent(for: id) {
            do {
                let attributedString = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(contentData) as! NSAttributedString
                let completeNote = Note(
                    id: metaNote.id,
                    title: metaNote.title,
                    content: attributedString,
                    createdAt: metaNote.createdAt,
                    updatedAt: metaNote.updatedAt
                )
                return completeNote
            } catch {
                print("解析笔记内容失败: \(error)")
                return metaNote
            }
        } else {
            print("未找到笔记内容文件，返回元数据")
            return metaNote
        }
    }
    
    // 检查存储状态，用于调试
    func checkStorageStatus() {
        print("=== 笔记存储状态检查 ===")
        print("笔记目录: \(notesDirectory.path)")
        print("笔记索引文件: \(notesIndexFile.path)")
        
        do {
            let fileExists = fileManager.fileExists(atPath: notesIndexFile.path)
            print("索引文件存在: \(fileExists)")
            
            if fileExists {
                let attributes = try fileManager.attributesOfItem(atPath: notesIndexFile.path)
                let fileSize = attributes[.size] as? UInt64 ?? 0
                print("索引文件大小: \(fileSize) 字节")
            }
            
            let indexNotes = loadNotesIndex()
            print("索引中笔记数量: \(indexNotes.count)")
            
            let filesInDirectory = try fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil)
            print("目录中文件数量: \(filesInDirectory.count)")
            for file in filesInDirectory {
                print("- \(file.lastPathComponent)")
            }
        } catch {
            print("检查存储状态时出错: \(error)")
        }
        
        print("========================")
    }
} 