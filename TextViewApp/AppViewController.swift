//
//  ViewController.swift
//  RichTextEditor
//
//  Created by 30594690 on 04/29/2025.
//  Copyright (c) 2025 30594690. All rights reserved.
//

import UIKit
import RichTextEditor

class AppViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        // Do any additional setup after loading the view, typically from a nib.
        let textEditor = RichTextEditor(configuration: RichTextEditorConfiguration())
        textEditor.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textEditor)
        NSLayoutConstraint.activate([
            textEditor.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textEditor.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textEditor.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            textEditor.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        Toolbar.shared.show(view: self.view)
    }
}
