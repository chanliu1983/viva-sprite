//
//  PixelArtEditorWindow.swift
//  VivaSprite
//
//  Pixel Art Editor Window for editing bone-attached pixel art
//

import Cocoa
import simd

protocol PixelArtEditorDelegate: AnyObject {
    func pixelArtEditor(_ editor: PixelArtEditorWindow, didUpdatePixelArt pixelArt: PixelArtData, for bone: Bone)
}

class PixelArtEditorWindow: NSWindowController {
    
    // MARK: - Properties
    
    weak var delegate: PixelArtEditorDelegate?
    private let bone: Bone
    private var pixelArt: PixelArtData
    
    // UI Components
    private var canvasView: PixelArtCanvasView!
    private var colorPalette: ColorPalette!
    private var toolSegmentedControl: NSSegmentedControl!
    private var sizeControls: NSStackView!
    private var anchorControls: NSStackView!
    private var nameTextField: NSTextField!
    
    // MARK: - Initialization
    
    init(bone: Bone) {
        self.bone = bone
        
        // Initialize or use existing pixel art
        if let existingPixelArt = bone.pixelArt {
            self.pixelArt = existingPixelArt
            print("Loading existing pixel art for bone: \(bone.name), size: \(existingPixelArt.width)x\(existingPixelArt.height)")
        } else {
            self.pixelArt = PixelArtData(name: "\(bone.name) Art", width: 32, height: 32)
            print("Creating new pixel art for bone: \(bone.name)")
        }
        
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Pixel Art Editor - \(bone.name)"
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        window.contentView = contentView
        
        setupToolbar()
        setupCanvasView()
        setupColorPalette()
        setupControls()
        setupLayout()
    }
    
    private func setupToolbar() {
        guard let window = window else { return }
        
        let toolbar = NSToolbar(identifier: "PixelArtEditorToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.isVisible = true
        window.toolbar = toolbar
    }
    
    private func setupCanvasView() {
        canvasView = PixelArtCanvasView()
        canvasView.pixelArt = pixelArt
        canvasView.delegate = self
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        
        print("Setting up canvas view with pixel art: \(pixelArt.name), size: \(pixelArt.width)x\(pixelArt.height)")
        print("Canvas view pixel art set: \(canvasView.pixelArt != nil ? "YES" : "NO")")
        
        // Force canvas to update its display
        canvasView.needsDisplay = true
    }
    
    private func setupColorPalette() {
        colorPalette = ColorPalette()
        colorPalette.delegate = self
        colorPalette.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the canvas view's initial color to match the selected color in the palette
        canvasView.currentColor = colorPalette.selectedColor
    }
    
    private func setupControls() {
        // Name field
        nameTextField = NSTextField()
        nameTextField.stringValue = pixelArt.name
        nameTextField.target = self
        nameTextField.action = #selector(nameChanged)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Tool control
        toolSegmentedControl = NSSegmentedControl()
        toolSegmentedControl.segmentCount = 2
        toolSegmentedControl.setLabel("Pen", forSegment: 0)
        toolSegmentedControl.setLabel("Eraser", forSegment: 1)
        toolSegmentedControl.selectedSegment = 0
        toolSegmentedControl.target = self
        toolSegmentedControl.action = #selector(toolChanged)
        toolSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Size controls
        setupSizeControls()
        
        // Anchor controls
        setupAnchorControls()
    }
    
    private func setupSizeControls() {
        sizeControls = NSStackView()
        sizeControls.orientation = .horizontal
        sizeControls.spacing = 8
        sizeControls.translatesAutoresizingMaskIntoConstraints = false
        
        let widthLabel = NSTextField(labelWithString: "Width:")
        let widthField = NSTextField()
        widthField.integerValue = pixelArt.width
        widthField.target = self
        widthField.action = #selector(sizeChanged)
        widthField.tag = 0 // width
        
        let heightLabel = NSTextField(labelWithString: "Height:")
        let heightField = NSTextField()
        heightField.integerValue = pixelArt.height
        heightField.target = self
        heightField.action = #selector(sizeChanged)
        heightField.tag = 1 // height
        
        let resizeButton = NSButton(title: "Resize", target: self, action: #selector(resizeCanvas))
        
        sizeControls.addArrangedSubview(widthLabel)
        sizeControls.addArrangedSubview(widthField)
        sizeControls.addArrangedSubview(heightLabel)
        sizeControls.addArrangedSubview(heightField)
        sizeControls.addArrangedSubview(resizeButton)
    }
    
    private func setupAnchorControls() {
        anchorControls = NSStackView()
        anchorControls.orientation = .horizontal
        anchorControls.spacing = 8
        anchorControls.translatesAutoresizingMaskIntoConstraints = false
        
        let anchorLabel = NSTextField(labelWithString: "Anchor:")
        
        let anchorXField = NSTextField()
        anchorXField.doubleValue = Double(pixelArt.anchorPoint.x)
        anchorXField.target = self
        anchorXField.action = #selector(anchorChanged)
        anchorXField.tag = 0 // x
        
        let anchorYField = NSTextField()
        anchorYField.doubleValue = Double(pixelArt.anchorPoint.y)
        anchorYField.target = self
        anchorYField.action = #selector(anchorChanged)
        anchorYField.tag = 1 // y
        
        let centerButton = NSButton(title: "Center", target: self, action: #selector(centerAnchor))
        
        anchorControls.addArrangedSubview(anchorLabel)
        anchorControls.addArrangedSubview(anchorXField)
        anchorControls.addArrangedSubview(anchorYField)
        anchorControls.addArrangedSubview(centerButton)
    }
    
    private func setupLayout() {
        guard let contentView = window?.contentView else { return }
        
        // Create main container
        let mainContainer = NSStackView()
        mainContainer.orientation = .vertical
        mainContainer.spacing = 8
        mainContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainContainer)
        
        // Create horizontal container for canvas and palette
        let horizontalContainer = NSStackView()
        horizontalContainer.orientation = .horizontal
        horizontalContainer.spacing = 8
        horizontalContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Create canvas container with scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.documentView = canvasView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        horizontalContainer.addArrangedSubview(scrollView)
        horizontalContainer.addArrangedSubview(colorPalette)
        
        // Add controls
        let controlsContainer = NSStackView()
        controlsContainer.orientation = .vertical
        controlsContainer.spacing = 8
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        controlsContainer.addArrangedSubview(nameTextField)
        controlsContainer.addArrangedSubview(toolSegmentedControl)
        controlsContainer.addArrangedSubview(sizeControls)
        controlsContainer.addArrangedSubview(anchorControls)
        
        mainContainer.addArrangedSubview(controlsContainer)
        mainContainer.addArrangedSubview(horizontalContainer)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            mainContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            colorPalette.widthAnchor.constraint(equalToConstant: 200),
            
            canvasView.widthAnchor.constraint(equalToConstant: CGFloat(pixelArt.width * 16)),
            canvasView.heightAnchor.constraint(equalToConstant: CGFloat(pixelArt.height * 16))
        ])
    }
    
    // MARK: - Actions
    
    @objc private func nameChanged(_ sender: NSTextField) {
        pixelArt.name = sender.stringValue
        updateBone()
    }
    
    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            canvasView.currentTool = .pen
        case 1:
            canvasView.currentTool = .eraser
        default:
            break
        }
    }
    
    @objc private func sizeChanged(_ sender: NSTextField) {
        // Size changes will be handled by resize button
    }
    
    @objc private func resizeCanvas(_ sender: NSButton) {
        guard let widthField = sizeControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 0 }),
              let heightField = sizeControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 1 }) else {
            return
        }
        
        let newWidth = max(1, min(128, widthField.integerValue))
        let newHeight = max(1, min(128, heightField.integerValue))
        
        resizePixelArt(to: newWidth, height: newHeight)
    }
    
    @objc private func anchorChanged(_ sender: NSTextField) {
        guard let xField = anchorControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 0 }),
              let yField = anchorControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 1 }) else {
            return
        }
        
        let x = max(0, min(1, Float(xField.doubleValue)))
        let y = max(0, min(1, Float(yField.doubleValue)))
        
        pixelArt.anchorPoint = simd_float2(x, y)
        updateBone()
    }
    
    @objc private func centerAnchor(_ sender: NSButton) {
        pixelArt.anchorPoint = simd_float2(0.5, 0.5)
        
        // Update UI
        if let xField = anchorControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 0 }),
           let yField = anchorControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 1 }) {
            xField.doubleValue = 0.5
            yField.doubleValue = 0.5
        }
        
        updateBone()
    }
    
    // MARK: - Helper Methods
    
    private func resizePixelArt(to width: Int, height: Int) {
        let oldPixels = pixelArt.pixels
        let oldWidth = pixelArt.width
        let oldHeight = pixelArt.height
        
        // Create new pixel array
        var newPixels = Array(repeating: Array(repeating: nil as NSColor?, count: width), count: height)
        
        // Copy existing pixels
        for row in 0..<min(height, oldHeight) {
            for col in 0..<min(width, oldWidth) {
                newPixels[row][col] = oldPixels[row][col]
            }
        }
        
        pixelArt.pixels = newPixels
        pixelArt.width = width
        pixelArt.height = height
        
        // Update canvas view
        canvasView.pixelArt = pixelArt
        canvasView.needsDisplay = true
        
        // Update constraints
        canvasView.removeFromSuperview()
        if let scrollView = canvasView.superview as? NSScrollView {
            scrollView.documentView = canvasView
        }
        
        updateBone()
    }
    
    private func updateBone() {
        print("Updating bone '\(bone.name)' with pixel art '\(pixelArt.name)'")
        let nonEmptyPixels = pixelArt.pixels.flatMap({ $0 }).compactMap({ $0 }).count
        print("Pixel art contains \(nonEmptyPixels) non-empty pixels out of \(pixelArt.width * pixelArt.height) total pixels")
        
        delegate?.pixelArtEditor(self, didUpdatePixelArt: pixelArt, for: bone)
        print("Delegate notified of pixel art update")
    }
}

// MARK: - NSWindowDelegate

extension PixelArtEditorWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        updateBone()
    }
}

// MARK: - NSToolbarDelegate

extension PixelArtEditorWindow: NSToolbarDelegate, NSToolbarItemValidation {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        switch itemIdentifier.rawValue {
        case "save":
            // Create a custom view toolbar item with a button for better control
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Save"
            item.paletteLabel = "Save"
            item.toolTip = "Save pixel art to the bone"
            
            // Create a custom button
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            button.bezelStyle = .texturedRounded
            button.isBordered = false
            button.title = ""
            
            if let saveImage = NSImage(systemSymbolName: "square.and.arrow.down.fill", accessibilityDescription: "Save") {
                button.image = saveImage
            }
            
            button.target = self
            button.action = #selector(savePixelArt)
            button.isEnabled = true
            
            item.view = button
            print("Creating custom save button with target: \(self) and action: \(#selector(savePixelArt))")
            
            return item
            

            
        default:
            return nil
        }
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("save"),
            .flexibleSpace
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("save"),
            .flexibleSpace
        ]
    }
    
    // Implement NSToolbarItemValidation protocol to ensure toolbar buttons are always enabled
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        // Always enable the save button
        if item.itemIdentifier.rawValue == "save" {
            print("Validating toolbar item: \(item.itemIdentifier.rawValue) - returning true")
            return true
        }
        print("Validating toolbar item: \(item.itemIdentifier.rawValue) - returning false")
        return false
    }
    
    @objc func savePixelArt() {
        print("Save button clicked - saving pixel art")
        
        // Ensure we have the latest pixel art data from the canvas
        if let canvasPixelArt = canvasView.pixelArt {
            pixelArt = canvasPixelArt
            print("Updated pixel art from canvas: \(pixelArt.name), size: \(pixelArt.width)x\(pixelArt.height)")
            
            let nonEmptyPixels = pixelArt.pixels.flatMap({ $0 }).compactMap({ $0 }).count
            print("Saving \(nonEmptyPixels) non-empty pixels to bone: \(bone.name)")
        }
        
        updateBone()
        print("Data saved, closing window")
        
        // Check if this window is presented as a sheet
        if let parentWindow = window?.sheetParent {
            print("Window is presented as sheet, ending sheet")
            parentWindow.endSheet(window!)
        } else {
            print("Window is not a sheet, closing normally")
            window?.close()
        }
    }
    
    @objc private func clearCanvas() {
        let alert = NSAlert()
        alert.messageText = "Clear Canvas"
        alert.informativeText = "Are you sure you want to clear the entire canvas?"
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            for row in 0..<pixelArt.height {
                for col in 0..<pixelArt.width {
                    pixelArt.pixels[row][col] = nil
                }
            }
            canvasView.needsDisplay = true
            updateBone()
        }
    }
}

// MARK: - ColorPaletteDelegate

extension PixelArtEditorWindow: ColorPaletteDelegate {
    func colorSelected(_ color: NSColor) {
        print("[DEBUG] colorSelected called with color: \(color)")
        canvasView.currentColor = color
    }
}

// MARK: - PixelArtCanvasViewDelegate

protocol PixelArtCanvasViewDelegate: AnyObject {
    func pixelArtCanvasDidChange(_ canvas: PixelArtCanvasView)
}

extension PixelArtEditorWindow: PixelArtCanvasViewDelegate {
    func pixelArtCanvasDidChange(_ canvas: PixelArtCanvasView) {
        updateBone()
    }
}