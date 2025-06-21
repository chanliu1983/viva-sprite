//
//  AppDelegate.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let window = NSApplication.shared.windows.first {
            let screenFrame = window.screen?.visibleFrame ?? NSRect.zero
            let newWidth: CGFloat = 1200
            let newHeight: CGFloat = 800
            let newX = (screenFrame.width - newWidth) / 2
            let newY = (screenFrame.height - newHeight) / 2
            let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
            window.setFrame(newFrame, display: true)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func exportSkeleton(_ sender: Any) {
        if let mainWindow = NSApplication.shared.mainWindow,
           let tabViewController = mainWindow.contentViewController as? TabViewController,
           let selectedItem = tabViewController.tabView.selectedTabViewItem,
           let skeletalController = selectedItem.viewController as? SkeletalDocumentViewController {
            skeletalController.exportSkeleton(sender)
        }
    }
    
    @IBAction func importSkeleton(_ sender: Any) {
        if let mainWindow = NSApplication.shared.mainWindow,
           let tabViewController = mainWindow.contentViewController as? TabViewController,
           let selectedItem = tabViewController.tabView.selectedTabViewItem,
           let skeletalController = selectedItem.viewController as? SkeletalDocumentViewController {
            skeletalController.importSkeleton(sender)
        }
    }
    
    @IBAction func exportAsImage(_ sender: Any) {
        if let mainWindow = NSApplication.shared.mainWindow,
           let tabViewController = mainWindow.contentViewController as? TabViewController,
           let selectedItem = tabViewController.tabView.selectedTabViewItem,
           let skeletalController = selectedItem.viewController as? SkeletalDocumentViewController {
            skeletalController.exportAsImage(sender)
        }
    }
    
    @IBAction func newSkeletalDocument(_ sender: Any) {
        if let mainWindow = NSApplication.shared.mainWindow,
           let tabViewController = mainWindow.contentViewController as? TabViewController {
            tabViewController.createNewDocument(type: .skeletal)
        }
    }
}