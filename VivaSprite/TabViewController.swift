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
        
        // Add right-click menu to tab view
        let menu = createTabContextMenu()
        tabView.menu = menu
        
        createNewDocument(type: .skeletal) // Create initial document
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
    
    func createNewDocument(type: DocumentType = .skeletal) {
        let storyboard = NSStoryboard(name: "Document", bundle: nil)
        
        switch type {
        case .pixelArt:
            guard let pixelArtVC = storyboard.instantiateController(withIdentifier: "DocumentViewController") as? DocumentViewController else {
                return
            }
            pixelArtVC.tabViewController = self
            pixelArtVC.documentName = "Untitled Pixel Art \(nextUntitledNumber)"
            let documentName = pixelArtVC.documentName
            let documentVC = pixelArtVC
            
            nextUntitledNumber += 1
            
            let tabViewItem = NSTabViewItem(viewController: documentVC)
            tabViewItem.label = documentName
            
            tabView.addTabViewItem(tabViewItem)
            tabView.selectTabViewItem(tabViewItem)
            
            documentControllers.append(documentVC)
            
        case .skeletal:
            // Show canvas size dialog asynchronously
            showCanvasSizeDialog { [weak self] width, height in
                guard let self = self else { return }
                
                let skeletalVC = SkeletalDocumentViewController()
                skeletalVC.tabViewController = self
                skeletalVC.documentName = "Untitled Skeleton \(self.nextUntitledNumber)"
                skeletalVC.setCanvasSize(width: width, height: height)
                let documentName = skeletalVC.documentName
                let documentVC = skeletalVC
                
                self.nextUntitledNumber += 1
                
                let tabViewItem = NSTabViewItem(viewController: documentVC)
                tabViewItem.label = documentName
                
                self.tabView.addTabViewItem(tabViewItem)
                self.tabView.selectTabViewItem(tabViewItem)
                
                self.documentControllers.append(documentVC)
            }
        }
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
    
    private func showCanvasSizeDialog(completion: @escaping (Int, Int) -> Void) {
        let alert = NSAlert()
        alert.icon = NSImage()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // Create a custom view for better visibility
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        
        // Width field with label
        let widthLabel = NSTextField(labelWithString: "Width:")
        widthLabel.frame = NSRect(x: 10, y: 60, width: 80, height: 20)
        widthLabel.font = NSFont.boldSystemFont(ofSize: 14)
        
        let widthField = NSTextField(frame: NSRect(x: 100, y: 60, width: 180, height: 24))
        widthField.stringValue = "1024"
        widthField.font = NSFont.systemFont(ofSize: 14)
        
        // Height field with label
        let heightLabel = NSTextField(labelWithString: "Height:")
        heightLabel.frame = NSRect(x: 10, y: 20, width: 80, height: 20)
        heightLabel.font = NSFont.boldSystemFont(ofSize: 14)
        
        let heightField = NSTextField(frame: NSRect(x: 100, y: 20, width: 180, height: 24))
        heightField.stringValue = "1024"
        heightField.font = NSFont.systemFont(ofSize: 14)
        
        // Add all elements to the custom view
        customView.addSubview(widthLabel)
        customView.addSubview(widthField)
        customView.addSubview(heightLabel)
        customView.addSubview(heightField)
        
        alert.accessoryView = customView
        
        guard let window = view.window else {
            // Fallback to default values if no window available
            completion(1024, 1024)
            return
        }
        
        alert.beginSheetModal(for: window) { response in
            // Get references to the width and height fields from the custom view
            let widthField = alert.accessoryView?.subviews.first(where: { $0 is NSTextField && $0.frame.origin.x == 100 && $0.frame.origin.y == 60 }) as? NSTextField
            let heightField = alert.accessoryView?.subviews.first(where: { $0 is NSTextField && $0.frame.origin.x == 100 && $0.frame.origin.y == 20 }) as? NSTextField
            if response == .alertFirstButtonReturn {
                // Safely unwrap the text field values
                let width = Int(widthField?.stringValue ?? "1024") ?? 1024
                let height = Int(heightField?.stringValue ?? "1024") ?? 1024
                completion(max(1, width), max(1, height))
            }
            // Don't call completion if cancelled - this prevents canvas creation
        }
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
            createNewDocument(type: .skeletal)
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

// MARK: - Context Menu
extension TabViewController {
    
    private func createTabContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let closeTabItem = NSMenuItem(title: "Close Tab", action: #selector(closeTabFromContextMenu(_:)), keyEquivalent: "")
        closeTabItem.target = self
        menu.addItem(closeTabItem)
        
        return menu
    }
    
    @objc private func closeTabFromContextMenu(_ sender: NSMenuItem) {
        // Get the tab view item that was right-clicked
        if let event = NSApp.currentEvent,
           let tabViewItem = getTabViewItemAt(event.locationInWindow) {
            // Get the view controller associated with this tab
            if let documentVC = tabViewItem.viewController {
                closeDocument(documentVC)
            }
        }
    }
    
    private func getTabViewItemAt(_ locationInWindow: NSPoint) -> NSTabViewItem? {
        // Convert window location to view coordinates
        let point = tabView.convert(locationInWindow, from: nil)
        
        // Check if the point is within any tab's frame
        for index in 0..<tabView.numberOfTabViewItems {
            let tabViewItem = tabView.tabViewItem(at: index)
            
            // Get the tab's frame (this is an approximation since NSTabView doesn't provide direct access to tab frames)
            // We're assuming tabs are at the top and have a standard height
            let tabRect = NSRect(x: 0, y: tabView.frame.height - 22, width: tabView.frame.width, height: 22)
            
            if tabRect.contains(point) {
                return tabViewItem
            }
        }
        
        return tabView.selectedTabViewItem
    }
}