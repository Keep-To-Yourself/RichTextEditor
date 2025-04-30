//
//  Toolbar.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/29.
//

import UIKit

public class Toolbar: UIView {
    
    public static let shared = Toolbar(configuration: ToolbarConfiguration())
    
    private weak var textEditor: RichTextEditor?
    private var configuration: ToolbarConfiguration
    
    private init(configuration: ToolbarConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        
        self.setConfiguration(configuration)
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.setTitle("完成", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameChanged),
                                               name: NSNotification.Name.UIKeyboardWillChangeFrame,
                                               object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func attach(to textEditor: RichTextEditor) {
        self.textEditor = textEditor
    }
    
    func detach() {
        self.textEditor = nil
    }
    
    public func show(view: UIView){
        self.removeFromSuperview()
        view.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightAnchor.constraint(equalToConstant: configuration.height)
        ])
    }
    
    public func setConfiguration(_ configuration: ToolbarConfiguration) {
        self.configuration = configuration
        
        self.backgroundColor = configuration.backgroundColor
    }
    
    @objc private func doneTapped() {
        self.textEditor?.endEditing(true)
    }
    
    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        let toolbarHeight = configuration.height
        let finalY = endFrame.origin.y - toolbarHeight
        
        UIView.animate(withDuration: duration) {
            self.frame.origin.y = finalY
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
