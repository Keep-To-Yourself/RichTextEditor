//
//  ToolbarView.swift
//  RichTextEditor
//
//  Created by Dylan Deng on 2025/4/29.
//

import UIKit

class ToolbarView: UIView {
    
    var doneAction: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor.systemGray
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        
        let button = UIButton(type: .system)
        button.setTitle("完成", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameChanged),
                                               name: NSNotification.Name.UIKeyboardWillChangeFrame,
                                               object: nil)
    }
    
    @objc private func doneTapped() {
        doneAction?()
    }
    
    @objc private func keyboardFrameChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        let screenHeight = UIScreen.main.bounds.height
        let targetY = endFrame.origin.y < screenHeight ? endFrame.origin.y - self.frame.height : screenHeight
        
        UIView.animate(withDuration: duration) {
            self.frame.origin.y = targetY
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
