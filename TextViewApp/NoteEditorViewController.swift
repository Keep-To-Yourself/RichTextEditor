import UIKit
import RichTextEditor

class NoteEditorViewController: UIViewController {
    
    private var note: Note?
    
    private var richTextEditor: RichTextEditor!
    
    init(id: UUID? = nil) {
        if id != nil {
            self.note = NoteStore.shared.getNote(byId: id!)
        }
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        navigationController?.isNavigationBarHidden = true
        
        // 添加自定义导航栏
        let navBar = UIView()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        
        // 返回按钮
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.addSubview(backButton)
        
        // 导航栏约束
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
            backButton.leadingAnchor.constraint(equalTo: navBar.leadingAnchor, constant: 16),
        ])
        
        // 初始化编辑器
        let configuration = RichTextEditorConfiguration(
            fontSize: 16,
            textColor: .darkGray,
            backgroundColor: .white
        )
        
        richTextEditor = RichTextEditor(
            configuration: configuration,
            document: self.note?.content
        )
        richTextEditor.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(richTextEditor)
        
        NSLayoutConstraint.activate([
            richTextEditor.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            richTextEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            richTextEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            richTextEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
        ])
        
        // 添加工具栏
        Toolbar.shared.show(view: view)
    }
    
    // 从第一行提取标题
    private func extractTitleFromContent(_ content: NSAttributedString) -> String {
        let fullText = content.string
        var firstLine = ""
        
        // 提取第一行，如果没有换行符，则使用全部内容
        if let newlineRange = fullText.range(of: "\n") {
            firstLine = String(fullText[..<newlineRange.lowerBound])
        } else {
            firstLine = fullText
        }
        
        // 如果第一行是空的，则使用"无标题笔记"
        let trimmedFirstLine = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFirstLine.isEmpty {
            return "无标题笔记"
        }
        
        // 限制标题长度，最多取前30个字符
        let maxLength = 30
        if trimmedFirstLine.count > maxLength {
            return String(trimmedFirstLine.prefix(maxLength)) + "..."
        }
        
        return trimmedFirstLine
    }
    
    @objc private func backButtonTapped() {
        if self.note == nil {
            NoteStore.shared.addNote(Note(
                title: "标题",
                content: self.richTextEditor.getDocument()
            ))
        } else {
            NoteStore.shared.updateNote(self.note!)
        }
        self.dismiss(animated: true)
    }
}
