import UIKit
import RichTextEditor

class NotesListViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let noteStore = NoteStore.shared
    private var cachedNotes: [Note] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
        self.modalTransitionStyle = .coverVertical
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        self.modalPresentationStyle = .fullScreen
        self.modalTransitionStyle = .coverVertical
        
        setupUI()
        
        // 检查存储状态
        noteStore.checkStorageStatus()
        
        // 加载笔记
        loadNotes()
        
        // 添加通知监听
        setupNotificationObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 每次视图即将显示时重新加载笔记
        loadNotes()
        tableView.reloadData()
    }
    
    private func setupNotificationObservers() {
        // 监听笔记数据变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNoteDataChanged),
            name: .noteDataChanged,
            object: nil
        )
    }
    
    @objc private func handleNoteDataChanged() {
        // 在主线程上执行刷新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("收到笔记数据变化通知，正在刷新列表")
            self.loadNotes()
            self.tableView.reloadData()
        }
    }
    
    deinit {
        // 移除通知监听
        NotificationCenter.default.removeObserver(self)
    }
    
    private func loadNotes() {
        cachedNotes = noteStore.notes.sorted(by: { $0.updatedAt > $1.updatedAt }) // 按更新时间排序，最新的在前
        print("加载了 \(cachedNotes.count) 条笔记")
        for note in cachedNotes {
            print("笔记: ID=\(note.id), 标题=\(note.title), 更新时间=\(dateFormatter.string(from: note.updatedAt))")
        }
    }
    
    private func setupUI() {
        title = "我的笔记"
        view.backgroundColor = .white
        
        // 设置导航栏
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )
        
        // 设置刷新控件
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshNotes), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // 设置TableView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "NoteCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func refreshNotes() {
        loadNotes()
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
    }
    
    @objc private func addButtonTapped() {
        let noteEditorVC = NoteEditorViewController()
        present(noteEditorVC, animated: true)
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension NotesListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cachedNotes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath)
        if cell.detailTextLabel == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "NoteCell")
        }
        
        let note = cachedNotes[indexPath.row]
        cell.textLabel?.text = note.title
        cell.detailTextLabel?.text = dateFormatter.string(from: note.updatedAt)
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let note = cachedNotes[indexPath.row]
        let noteEditorVC = NoteEditorViewController(id: note.id)
        present(noteEditorVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let note = cachedNotes[indexPath.row]
            noteStore.deleteNote(withId: note.id)
            loadNotes() // 重新加载笔记列表
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
