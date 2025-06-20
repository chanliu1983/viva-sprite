//
//  TabViewController.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

enum DocumentType {
    case pixelArt
    case skeletal
}

class TabViewController: NSViewController {
    
    @IBOutlet weak var tabView: NSTabView!
    
    private var documentControllers: [NSViewController] = []
    private var nextUntitledNumber = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabView()
        createNewDocument(type: .pixelArt) // Create initial document
    }
    
    private func setupTabView() {
        tabView.delegate = self
        
        // Set tab view style
        tabView.tabViewType = .topTabsBezelBorder
        tabView.allowsTruncatedLabels = true
        tabView.drawsBackground = true
        
        // Make sure the tab view is visible and properly sized
        tabView.isHidden = false
        tabView.frame = view.bounds
        tabView.autoresizingMask = [.width, .height]
        
        // Ensure the tab view has a background color
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    func createNewDocument(type: DocumentType = .pixelArt) {
        let storyboard = NSStoryboard(name: "Document", bundle: nil)
        
        let documentVC: NSViewController
        let documentName: String
        
        switch type {
        case .pixelArt:
            guard let pixelArtVC = storyboard.instantiateController(withIdentifier: "DocumentViewController") as? DocumentViewController else {
                return
            }
            pixelArtVC.tabViewController = self
            pixelArtVC.documentName = "Untitled Pixel Art \(nextUntitledNumber)"
            documentName = pixelArtVC.documentName
            documentVC = pixelArtVC
            
        case .skeletal:
            let skeletalVC = SkeletalDocumentViewController()
            skeletalVC.tabViewController = self
            skeletalVC.documentName = "Untitled Skeleton \(nextUntitledNumber)"
            documentName = skeletalVC.documentName
            documentVC = skeletalVC
        }
        
        nextUntitledNumber += 1
        
        let tabViewItem = NSTabViewItem(viewController: documentVC)
        tabViewItem.label = documentName
        
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
    
    func closeDocument(_ documentVC: NSViewController) {
        guard let index = documentControllers.firstIndex(where: { $0 === documentVC }) else { return }
        
        let tabViewItem = tabView.tabViewItems[index]
        tabView.removeTabViewItem(tabViewItem)
        documentControllers.remove(at: index)
        
        // If no documents left, create a new one
        if documentControllers.isEmpty {
            createNewDocument(type: .pixelArt)
        }
    }
    
    func updateTabTitle(for documentVC: NSViewController, title: String) {
        guard let index = documentControllers.firstIndex(where: { $0 === documentVC }) else { return }
        let tabViewItem = tabView.tabViewItems[index]
        tabViewItem.label = title
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