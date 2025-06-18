//
//  DocumentViewController.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

class DocumentViewController: NSViewController {
    
    @IBOutlet weak var canvasView: CanvasView!
    @IBOutlet weak var colorPalette: ColorPalette!
    @IBOutlet weak var toolSegmentedControl: NSSegmentedControl!
    
    private var toolManager = ToolManager()
    var documentName: String = "Untitled"
    var isModified: Bool = false {
        didSet {
            updateTabTitle()
        }
    }
    
    weak var tabViewController: TabViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupToolManager()
    }
    
    private func setupUI() {
        // Set up the main view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Configure tool segmented control (already set up in storyboard)
        toolSegmentedControl.selectedSegment = 0
        
        // Set up canvas
        canvasView.toolManager = toolManager
        canvasView.documentViewController = self
        
        // Set up color palette
        colorPalette.delegate = self
        
        // Set initial tool
        toolManager.currentTool = .pen
    }
    
    private func setupToolManager() {
        toolManager.currentColor = NSColor.black
        toolManager.brushSize = 1
    }
    
    private func updateTabTitle() {
        let title = isModified ? "\(documentName) •" : documentName
        tabViewController?.updateTabTitle(for: self, title: title)
    }
    
    @IBAction func toolChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            toolManager.currentTool = .pen
        case 1:
            toolManager.currentTool = .eraser
        default:
            break
        }
    }
    
    @IBAction func clearCanvas(_ sender: Any) {
        canvasView.clearCanvas()
        markAsModified()
    }
    
    func openImage(from url: URL) {
        canvasView.loadImage(from: url)
        documentName = url.deletingPathExtension().lastPathComponent
        isModified = false
    }
    
    func saveImage(to url: URL) {
        canvasView.saveImage(to: url)
        documentName = url.deletingPathExtension().lastPathComponent
        isModified = false
    }
    
    func markAsModified() {
        isModified = true
    }
    
    func markAsClean() {
        isModified = false
    }
}

// MARK: - ColorPaletteDelegate
extension DocumentViewController: ColorPaletteDelegate {
    func colorSelected(_ color: NSColor) {
        toolManager.currentColor = color
    }
}