//
//  ViewController.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

class ViewController: NSViewController {
    
    private var tabViewController: TabViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabViewController()
    }
    
    private func setupTabViewController() {
        let storyboard = NSStoryboard(name: "Document", bundle: nil)
        tabViewController = storyboard.instantiateController(withIdentifier: "TabViewController") as? TabViewController
        
        if let tabVC = tabViewController {
            addChild(tabVC)
            view.addSubview(tabVC.view)
            
            // Set up constraints
            tabVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tabVC.view.topAnchor.constraint(equalTo: view.topAnchor),
                tabVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tabVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tabVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }
    
    @IBAction func clearCanvas(_ sender: Any) {
        tabViewController?.getCurrentDocumentViewController()?.clearCanvas(sender)
    }
    
    @IBAction func newDocument(_ sender: Any) {
        tabViewController?.createNewDocument()
    }
    
    @IBAction func openImage(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                self.tabViewController?.openDocument(from: url)
            }
        }
    }
    
    @IBAction func saveImage(_ sender: Any) {
        tabViewController?.saveCurrentDocument()
    }
    
    @IBAction func closeDocument(_ sender: Any) {
        tabViewController?.closeCurrentDocument()
    }
}

// MARK: - Menu Validation
extension ViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Enable all menu items by default
        return true
    }
}