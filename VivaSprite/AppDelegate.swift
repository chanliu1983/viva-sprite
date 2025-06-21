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
        // Insert code here to initialize your application
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
}