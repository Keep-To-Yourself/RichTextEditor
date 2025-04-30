//
//  ViewController.swift
//  RichTextEditor
//
//  Created by 30594690 on 04/29/2025.
//  Copyright (c) 2025 30594690. All rights reserved.
//

import UIKit
import RichTextEditor

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let editorView = EditorView(frame: self.view.bounds)
        view.addSubview(editorView)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
