//
//  ViewController.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var canvasView: CanvasView!
    @IBOutlet weak var colorPalette: ColorPalette!
    @IBOutlet weak var toolSegmentedControl: NSSegmentedControl!
    
    private var toolManager = ToolManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupToolManager()
    }
    
    private func setupUI() {
        // Set up the main window
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Configure tool segmented control
        toolSegmentedControl.segmentCount = 2
        toolSegmentedControl.setLabel("Pen", forSegment: 0)
        toolSegmentedControl.setLabel("Eraser", forSegment: 1)
        toolSegmentedControl.selectedSegment = 0
        
        // Set up canvas
        canvasView.toolManager = toolManager
        
        // Set up color palette
        colorPalette.delegate = self
        
        // Set initial tool
        toolManager.currentTool = .pen
    }
    
    private func setupToolManager() {
        toolManager.currentColor = NSColor.black
        toolManager.brushSize = 1
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
    }
    
    @IBAction func openImage(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                self.canvasView.loadImage(from: url)
            }
        }
    }
    
    @IBAction func saveImage(_ sender: Any) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "pixel_art.png"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                self.canvasView.saveImage(to: url)
            }
        }
    }
}

// MARK: - Menu Validation
extension ViewController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Enable all menu items by default
        return true
    }
}

// MARK: - ColorPaletteDelegate
extension ViewController: ColorPaletteDelegate {
    func colorSelected(_ color: NSColor) {
        toolManager.currentColor = color
    }
}