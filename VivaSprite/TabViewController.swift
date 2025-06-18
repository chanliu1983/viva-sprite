//
//  TabViewController.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

class TabViewController: NSViewController {
    
    @IBOutlet weak var tabView: NSTabView!
    
    private var documentControllers: [DocumentViewController] = []
    private var nextUntitledNumber = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabView()
        createNewDocument() // Create initial document
    }
    
    private func setupTabView() {
        tabView.delegate = self
        tabView.tabViewType = .topTabsBezelBorder
        tabView.allowsTruncatedLabels = false
        tabView.drawsBackground = true
    }
    
    func createNewDocument() {
        let storyboard = NSStoryboard(name: "Document", bundle: nil)
        guard let documentVC = storyboard.instantiateController(withIdentifier: "DocumentViewController") as? DocumentViewController else {
            return
        }
        
        documentVC.tabViewController = self
        documentVC.documentName = "Untitled \(nextUntitledNumber)"
        nextUntitledNumber += 1
        
        let tabViewItem = NSTabViewItem(viewController: documentVC)
        tabViewItem.label = documentVC.documentName
        
        tabView.addTabViewItem(tabViewItem)
        tabView.selectTabViewItem(tabViewItem)
        
        documentControllers.append(documentVC)
    }
    
    func openDocument(from url: URL) {
        let storyboard = NSStoryboard(name: "Document", bundle: nil)
        guard let documentVC = storyboard.instantiateController(withIdentifier: "DocumentViewController") as? DocumentViewController else {
            return
        }
        
        documentVC.tabViewController = self
        
        // Ensure the view is loaded before accessing outlets
        documentVC.loadView()
        documentVC.viewDidLoad()
        
        documentVC.openImage(from: url)
        
        let tabViewItem = NSTabViewItem(viewController: documentVC)
        tabViewItem.label = documentVC.documentName
        
        tabView.addTabViewItem(tabViewItem)
        tabView.selectTabViewItem(tabViewItem)
        
        documentControllers.append(documentVC)
    }
    
    func closeCurrentDocument() {
        guard let selectedItem = tabView.selectedTabViewItem,
              let documentVC = selectedItem.viewController as? DocumentViewController else {
            return
        }
        
        if documentVC.isModified {
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes to \"\(documentVC.documentName)\"?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: // Save
                saveCurrentDocument()
                return
            case .alertSecondButtonReturn: // Don't Save
                break
            case .alertThirdButtonReturn: // Cancel
                return
            default:
                return
            }
        }
        
        if let index = documentControllers.firstIndex(of: documentVC) {
            documentControllers.remove(at: index)
        }
        
        tabView.removeTabViewItem(selectedItem)
        
        // If no tabs left, create a new document
        if tabView.numberOfTabViewItems == 0 {
            createNewDocument()
        }
    }
    
    func saveCurrentDocument() {
        guard let selectedItem = tabView.selectedTabViewItem,
              let documentVC = selectedItem.viewController as? DocumentViewController else {
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(documentVC.documentName).png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                documentVC.saveImage(to: url)
            }
        }
    }
    
    func getCurrentDocumentViewController() -> DocumentViewController? {
        guard let selectedItem = tabView.selectedTabViewItem,
              let documentVC = selectedItem.viewController as? DocumentViewController else {
            return nil
        }
        return documentVC
    }
    
    func updateTabTitle(for documentVC: DocumentViewController, title: String) {
        for tabViewItem in tabView.tabViewItems {
            if tabViewItem.viewController === documentVC {
                tabViewItem.label = title
                break
            }
        }
    }
}

// MARK: - NSTabViewDelegate
extension TabViewController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Handle tab selection if needed
    }
    
    func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        return true
    }
}