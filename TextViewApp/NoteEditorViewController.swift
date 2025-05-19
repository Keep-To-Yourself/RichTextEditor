import UIKit
import RichTextEditor

enum NoteEditorMode: Equatable {
    case new
    case edit(noteId: UUID)
    
    static func == (lhs: NoteEditorMode, rhs: NoteEditorMode) -> Bool {
        switch (lhs, rhs) {
        case (.new, .new):
            return true
        case (.edit(let lhsId), .edit(let rhsId)):
            return lhsId == rhsId
        default:
            return false
        }
    }
}

class NoteEditorViewController: UIViewController {
    
    private let mode: NoteEditorMode
    private let noteStore = NoteStore.shared
    private var currentNote: Note?
    
    private var richTextEditor: RichTextEditor!
    private var textView: UITextView? // 直接引用内部的UITextView
    private var toolbarContainerView: UIView!
    
    init(mode: NoteEditorMode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadNoteData()
        
        // 注册键盘通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        // 监听键盘帧变化，处理键盘大小调整
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 更新工具栏位置，确保它在底部（如果键盘没有显示）
        if textView?.isFirstResponder != true {
            let toolbarHeight: CGFloat = 44
            toolbarContainerView.frame = CGRect(
                x: 0,
                y: view.bounds.height - toolbarHeight,
                width: view.bounds.width,
                height: toolbarHeight
            )
        }
        
        // 每次布局更新后确保工具栏在最前面
        view.bringSubviewToFront(toolbarContainerView)
        
        // 打印工具栏的位置用于调试
        print("工具栏位置更新 - frame: \(toolbarContainerView.frame)")
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
            
            let toolbarHeight: CGFloat = 44
            
            // 修正计算，使用view.frame而不是键盘位置来计算工具栏位置
            // 键盘的origin.y是相对于屏幕的，而我们需要相对于view的位置
            
            // 将键盘框架转换为视图坐标系统
            let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
            
            // 工具栏应该位于键盘之上的位置
            let newY = keyboardFrameInView.origin.y - toolbarHeight
            
            // 确保工具栏在键盘上方，并且总是在最前面
            view.bringSubviewToFront(toolbarContainerView)
            
            UIView.animate(withDuration: animationDuration) {
                self.toolbarContainerView.frame = CGRect(
                    x: 0,
                    y: newY,
                    width: self.view.bounds.width,
                    height: toolbarHeight
                )
            }
            
            // 打印调试信息
            print("键盘显示 - 键盘在视图中的位置: \(keyboardFrameInView.origin.y), 工具栏新位置: \(newY)")
            print("视图高度: \(view.bounds.height), 键盘高度: \(keyboardFrame.height)")
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        if let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
            UIView.animate(withDuration: animationDuration) {
                // 键盘隐藏时将工具栏放回底部
                let toolbarHeight: CGFloat = 44
                self.toolbarContainerView.frame = CGRect(
                    x: 0,
                    y: self.view.bounds.height - toolbarHeight,
                    width: self.view.bounds.width,
                    height: toolbarHeight
                )
                
                // 打印工具栏的位置用于调试
                print("键盘隐藏 - 工具栏位置更新: \(self.toolbarContainerView.frame)")
            }
        }
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        // 在键盘帧变化时也要更新工具栏位置
        keyboardWillShow(notification)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // 配置导航栏
        title = mode == .new ? "新建笔记" : "编辑笔记"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveButtonTapped)
        )
        
        // 配置富文本编辑器 - 保持原有的配置
        let configuration = RichTextEditorConfiguration(
            fontSize: 16,
            textColor: .darkGray,
            backgroundColor: .white
        )
        richTextEditor = RichTextEditor(configuration: configuration)
        richTextEditor.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(richTextEditor)
        
        // 创建一个容器视图来持有工具栏 - 使用frame布局而不是自动布局约束
        let toolbarHeight: CGFloat = 44
        toolbarContainerView = UIView(frame: CGRect(
            x: 0,
            y: view.bounds.height - toolbarHeight,
            width: view.bounds.width,
            height: toolbarHeight
        ))
        toolbarContainerView.backgroundColor = .systemGray6
        toolbarContainerView.layer.borderColor = UIColor.lightGray.cgColor
        toolbarContainerView.layer.borderWidth = 0.5
        toolbarContainerView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin] // 自动调整宽度和顶部边距
        view.addSubview(toolbarContainerView)
        
        // 创建一个"完成"按钮代替工具栏
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("完成", for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        
        toolbarContainerView.addSubview(doneButton)
        
        NSLayoutConstraint.activate([
            doneButton.trailingAnchor.constraint(equalTo: toolbarContainerView.trailingAnchor, constant: -12),
            doneButton.centerYAnchor.constraint(equalTo: toolbarContainerView.centerYAnchor)
        ])
        
        // 获取内部的UITextView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.findTextView()
        }
        
        // 设置约束 - 富文本编辑器占满整个视图，底部留出工具栏的空间
        NSLayoutConstraint.activate([
            richTextEditor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            richTextEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            richTextEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            richTextEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -toolbarHeight) // 为工具栏留出空间
        ])
        
        // 确保工具栏视图在最前
        view.bringSubviewToFront(toolbarContainerView)
        
        // 打印视图层次结构，用于调试
        print("视图层次: \(view.subviews)")
    }
    
    private func findTextView() {
        // 递归查找子视图中的UITextView
        func findTextViewIn(view: UIView) -> UITextView? {
            for subview in view.subviews {
                if let textView = subview as? UITextView {
                    return textView
                }
                if let foundTextView = findTextViewIn(view: subview) {
                    return foundTextView
                }
            }
            return nil
        }
        
        textView = findTextViewIn(view: richTextEditor)
        print("找到TextEditor: \(textView != nil)")
    }
    
    private func loadNoteData() {
        switch mode {
        case .new: break
            // 不做任何修改，使用RichTextEditor组件内置的初始化内容
            
        case .edit(let noteId):
            if let note = noteStore.getNote(byId: noteId) {
                currentNote = note
                
                // 从note中获取NSAttributedString并设置到编辑器中
                let attributedContent = note.getAttributedContent()
                
                // 异步设置内容，确保textView已经找到
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.setAttributedContent(attributedContent)
                }
            }
        }
    }
    
    private func setAttributedContent(_ content: NSAttributedString) {
        if let textView = self.textView {
            textView.attributedText = content
            print("成功设置富文本内容到textView")
        } else {
            // 尝试直接从richTextEditor的子视图获取
            if let textView = richTextEditor.subviews.first as? UITextView {
                textView.attributedText = content
                print("通过子视图设置富文本内容")
            } else {
                print("未找到textView，无法设置内容")
            }
        }
    }
    
    private func getCurrentAttributedContent() -> NSAttributedString {
        // 首先尝试使用存储的引用
        if let textView = self.textView {
            print("从缓存的textView获取富文本内容，长度：\(textView.attributedText.length)")
            return textView.attributedText
        }
        
        // 然后尝试直接从子视图获取
        for subview in richTextEditor.subviews {
            if let textView = subview as? UITextView {
                print("从子视图获取富文本内容，长度：\(textView.attributedText.length)")
                return textView.attributedText
            }
        }
        
        // 递归查找子视图
        func findTextViewAttributedText(in view: UIView) -> NSAttributedString? {
            for subview in view.subviews {
                if let textView = subview as? UITextView {
                    return textView.attributedText
                }
                if let result = findTextViewAttributedText(in: subview) {
                    return result
                }
            }
            return nil
        }
        
        if let attributedText = findTextViewAttributedText(in: richTextEditor) {
            print("通过递归查找获取富文本内容，长度：\(attributedText.length)")
            return attributedText
        }
        
        print("无法获取富文本内容，返回空字符串")
        return NSAttributedString(string: "")
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
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        let attributedContent = getCurrentAttributedContent()
        
        // 从内容中提取标题
        let title = extractTitleFromContent(attributedContent)
        print("从内容中提取标题：\(title)，内容长度：\(attributedContent.length)")
        
        // 检查内容是否为空
        let contentText = attributedContent.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if contentText.isEmpty {
            showAlert(message: "请输入笔记内容")
            return
        }
        
        switch mode {
        case .new:
            let newNote = Note(
                title: title,
                content: attributedContent
            )
            noteStore.addNote(newNote)
            print("新笔记已保存，ID: \(newNote.id)")
            
        case .edit:
            if var updatedNote = currentNote {
                updatedNote.title = title
                updatedNote.updateContent(attributedContent)
                noteStore.updateNote(updatedNote)
                print("笔记已更新，ID: \(updatedNote.id)")
            }
        }
        
        // 显示保存成功提示
        showSavedSuccessToast()
    }
    
    @objc private func doneButtonTapped() {
        textView?.resignFirstResponder()
    }
    
    private func showSavedSuccessToast() {
        // 创建提示视图
        let toastView = UIView()
        toastView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastView.layer.cornerRadius = 10
        toastView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "保存成功"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        toastView.addSubview(label)
        view.addSubview(toastView)
        
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            toastView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            toastView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            label.centerXAnchor.constraint(equalTo: toastView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: toastView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -8)
        ])
        
        // 弹出动画
        toastView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            toastView.alpha = 1
        }
        
        // 0.8秒后关闭编辑器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            UIView.animate(withDuration: 0.2, animations: {
                toastView.alpha = 0
            }, completion: { _ in
                toastView.removeFromSuperview()
                self?.dismiss(animated: true)
            })
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(
            title: "提示",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            // 在动画过程中不做任何操作
        }, completion: { _ in
            // 旋转完成后重新布局工具栏
            if self.textView?.isFirstResponder == true {
                // 如果键盘可见，确保工具栏在键盘上方
                // 获取当前键盘位置
                if let keyboardWindow = UIApplication.shared.windows.last,
                   let keyboardView = keyboardWindow.subviews.first(where: { $0.description.contains("Keyboard") }) {
                    
                    // 获取键盘在视图中的位置
                    let keyboardFrameInWindow = keyboardView.frame
                    let keyboardFrameInView = self.view.convert(keyboardFrameInWindow, from: nil)
                    
                    let toolbarHeight: CGFloat = 44
                    let newY = keyboardFrameInView.origin.y - toolbarHeight
                    
                    self.toolbarContainerView.frame = CGRect(
                        x: 0,
                        y: newY,
                        width: size.width,
                        height: toolbarHeight
                    )
                    
                    print("旋转后 - 重新定位工具栏: \(self.toolbarContainerView.frame)")
                } else {
                    // 如果无法获取键盘位置，则默认放在底部
                    let toolbarHeight: CGFloat = 44
                    self.toolbarContainerView.frame = CGRect(
                        x: 0,
                        y: size.height - toolbarHeight,
                        width: size.width,
                        height: toolbarHeight
                    )
                }
            } else {
                // 否则将工具栏放在底部
                let toolbarHeight: CGFloat = 44
                self.toolbarContainerView.frame = CGRect(
                    x: 0,
                    y: size.height - toolbarHeight,
                    width: size.width,
                    height: toolbarHeight
                )
            }
            
            // 确保工具栏在最前
            self.view.bringSubviewToFront(self.toolbarContainerView)
        })
    }
} 
