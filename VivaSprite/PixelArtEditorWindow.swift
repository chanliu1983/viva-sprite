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
    private var brushSizeControls: NSStackView!

    private var nameTextField: NSTextField!
    private var importButton: NSButton!
    private var debugInfoLabel: NSTextField!
    private var zoomControls: NSStackView!
    private var zoomLabel: NSTextField!
    private var zoomFactor: CGFloat = 1.0
    
    private func updateCurrentColorView() {
        currentColorView.layer?.backgroundColor = canvasView.currentColor.cgColor
    }
    private var currentColorView: NSView! // Add this property for current color display
    
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
        // Perform initial auto-zoom after UI is fully set up
        calculateAutoZoom()
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
        // Name field (read-only)
        nameTextField = NSTextField(labelWithString: pixelArt.name)
        nameTextField.isEditable = false
        nameTextField.isSelectable = false
        nameTextField.isBezeled = false
        nameTextField.drawsBackground = false
        nameTextField.font = NSFont.boldSystemFont(ofSize: 13)
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Tool control with icons
        toolSegmentedControl = NSSegmentedControl()
        toolSegmentedControl.segmentCount = 4 // Add color picker tool
        // Set icons for each tool
        if let penIcon = NSImage(systemSymbolName: "pencil", accessibilityDescription: "Pen") {
            toolSegmentedControl.setImage(penIcon, forSegment: 0)
        }
        toolSegmentedControl.setLabel("Pen", forSegment: 0)
        if let eraserIcon = NSImage(systemSymbolName: "eraser", accessibilityDescription: "Eraser") {
            toolSegmentedControl.setImage(eraserIcon, forSegment: 1)
        }
        toolSegmentedControl.setLabel("Eraser", forSegment: 1)
        if let panIcon = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "Pan") {
            toolSegmentedControl.setImage(panIcon, forSegment: 2)
        }
        toolSegmentedControl.setLabel("Pan", forSegment: 2)
        if let pickerIcon = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Color Picker") {
            toolSegmentedControl.setImage(pickerIcon, forSegment: 3)
        }
        toolSegmentedControl.setLabel("Picker", forSegment: 3)
        toolSegmentedControl.selectedSegment = 0
        toolSegmentedControl.target = self
        toolSegmentedControl.action = #selector(toolChanged)
        toolSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Current color view
        currentColorView = NSView()
        currentColorView.wantsLayer = true
        currentColorView.layer?.borderColor = NSColor.gray.cgColor
        currentColorView.layer?.borderWidth = 1
        currentColorView.translatesAutoresizingMaskIntoConstraints = false
        updateCurrentColorView()
        
        // Brush size controls
        setupBrushSizeControls()
        

        
        // Import button
        setupImportButton()
        
        // Debug info
        setupDebugInfo()
        
        // Zoom controls
        setupZoomControls()
    }
    

    
    private func setupBrushSizeControls() {
        brushSizeControls = NSStackView()
        brushSizeControls.orientation = .horizontal
        brushSizeControls.spacing = 8
        brushSizeControls.translatesAutoresizingMaskIntoConstraints = false
        
        let brushSizeLabel = NSTextField(labelWithString: "Brush Size:")
        
        let brushSizeSlider = NSSlider()
        brushSizeSlider.minValue = 1
        brushSizeSlider.maxValue = 5
        brushSizeSlider.integerValue = 1
        brushSizeSlider.numberOfTickMarks = 5
        brushSizeSlider.allowsTickMarkValuesOnly = true
        brushSizeSlider.tickMarkPosition = .below
        brushSizeSlider.target = self
        brushSizeSlider.action = #selector(brushSizeChanged)
        brushSizeSlider.translatesAutoresizingMaskIntoConstraints = false
        
        let brushSizeValueLabel = NSTextField(labelWithString: "1")
        brushSizeValueLabel.tag = 999 // Use a unique tag to identify this label
        brushSizeValueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        brushSizeControls.addArrangedSubview(brushSizeLabel)
        brushSizeControls.addArrangedSubview(brushSizeSlider)
        brushSizeControls.addArrangedSubview(brushSizeValueLabel)
        
        // Set slider width constraint
        NSLayoutConstraint.activate([
            brushSizeSlider.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    

    
    private func setupImportButton() {
        importButton = NSButton(title: "Import Image", target: self, action: #selector(importImage))
        importButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupDebugInfo() {
        debugInfoLabel = NSTextField(labelWithString: "Canvas Size: \(pixelArt.width) x \(pixelArt.height)")
        debugInfoLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        debugInfoLabel.textColor = NSColor.secondaryLabelColor
        debugInfoLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupZoomControls() {
        zoomControls = NSStackView()
        zoomControls.orientation = .horizontal
        zoomControls.spacing = 8
        zoomControls.translatesAutoresizingMaskIntoConstraints = false
        
        let zoomTitleLabel = NSTextField(labelWithString: "Zoom:")
        
        let zoomOutButton = NSButton(title: "-", target: self, action: #selector(zoomOut))
        zoomOutButton.bezelStyle = .rounded
        
        zoomLabel = NSTextField(labelWithString: "100%")
        zoomLabel.alignment = .center
        zoomLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let zoomInButton = NSButton(title: "+", target: self, action: #selector(zoomIn))
        zoomInButton.bezelStyle = .rounded
        
        zoomControls.addArrangedSubview(zoomTitleLabel)
        zoomControls.addArrangedSubview(zoomOutButton)
        zoomControls.addArrangedSubview(zoomLabel)
        zoomControls.addArrangedSubview(zoomInButton)
        
        // Set zoom label width constraint
        NSLayoutConstraint.activate([
            zoomLabel.widthAnchor.constraint(equalToConstant: 50)
        ])
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

        let toolAndColorContainer = NSStackView(views: [toolSegmentedControl, currentColorView])
        toolAndColorContainer.orientation = .horizontal
        toolAndColorContainer.spacing = 8
        controlsContainer.addArrangedSubview(toolAndColorContainer)

        controlsContainer.addArrangedSubview(brushSizeControls)
        controlsContainer.addArrangedSubview(zoomControls)
        controlsContainer.addArrangedSubview(importButton)
        controlsContainer.addArrangedSubview(debugInfoLabel)
        
        mainContainer.addArrangedSubview(controlsContainer)
        mainContainer.addArrangedSubview(horizontalContainer)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            mainContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            currentColorView.widthAnchor.constraint(equalToConstant: 30),
            currentColorView.heightAnchor.constraint(equalTo: toolSegmentedControl.heightAnchor),
            
            colorPalette.widthAnchor.constraint(equalToConstant: 200),
            
            canvasView.widthAnchor.constraint(equalToConstant: CGFloat(pixelArt.width * 16)),
            canvasView.heightAnchor.constraint(equalToConstant: CGFloat(pixelArt.height * 16))
        ])
    }
    
    // MARK: - Actions
    

    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            canvasView.currentTool = .pen
        case 1:
            canvasView.currentTool = .eraser
        case 2:
            canvasView.currentTool = .pan
        case 3:
            canvasView.currentTool = .picker
        default:
            break
        }
    }
    
    @objc private func zoomIn(_ sender: NSButton) {
        let newZoom = min(zoomFactor * 1.5, 8.0)
        setZoom(newZoom)
    }
    
    @objc private func zoomOut(_ sender: NSButton) {
        let newZoom = max(zoomFactor / 1.5, 0.25)
        setZoom(newZoom)
    }
    
    private func setZoom(_ zoom: CGFloat) {
        zoomFactor = zoom
        canvasView.zoomFactor = zoom
        updateZoomLabel()
    }
    
    private func updateZoomLabel() {
        let percentage = Int(zoomFactor * 100)
        zoomLabel.stringValue = "\(percentage)%"
    }
    
    private func calculateAutoZoom() {
        guard let window = window else { return }
        
        // Ensure pixelArt is available
        guard pixelArt.width > 0 && pixelArt.height > 0 else {
            print("Cannot calculate auto-zoom: pixelArt dimensions are invalid")
            return
        }
        
        // Get available canvas area (roughly 60% of window for canvas)
        let availableWidth = window.frame.width * 0.6
        let availableHeight = window.frame.height * 0.7
        
        // Calculate required size at 1x zoom
        let imageWidth = CGFloat(pixelArt.width) * 16.0 // pixelSize is 16.0
        let imageHeight = CGFloat(pixelArt.height) * 16.0
        
        // Calculate zoom factors to fit width and height
        let zoomForWidth = availableWidth / imageWidth
        let zoomForHeight = availableHeight / imageHeight
        
        // Use the smaller zoom factor to ensure image fits completely
        let autoZoom = min(zoomForWidth, zoomForHeight, 8.0) // Cap at 8x zoom
        let finalZoom = max(autoZoom, 0.25) // Minimum 0.25x zoom
        
        setZoom(finalZoom)
        print("Auto-zoom calculated: \(finalZoom)x for image size \(pixelArt.width)x\(pixelArt.height)")
    }
    
    @objc private func brushSizeChanged(_ sender: NSSlider) {
        let brushSize = sender.integerValue
        canvasView.brushSize = brushSize
        
        // Update the value label
        if let valueLabel = brushSizeControls.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 999 }) {
            valueLabel.stringValue = "\(brushSize)"
        }
    }
    

    
    @objc private func importImage(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { [weak self] response in
            guard response == .OK,
                  let url = openPanel.url,
                  let image = NSImage(contentsOf: url),
                  let self = self else {
                return
            }
            
            self.importImageToCanvas(image)
        }
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
        
        // Update canvas size constraints
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.widthAnchor.constraint(equalToConstant: CGFloat(pixelArt.width * 16)),
            canvasView.heightAnchor.constraint(equalToConstant: CGFloat(pixelArt.height * 16))
        ])
        
        
        
        // Apply auto-zoom to fit the imported image
        calculateAutoZoom()

        updateBone()
        updateDebugInfo()
    }
    
    private func updateDebugInfo() {
        debugInfoLabel.stringValue = "Canvas Size: \(pixelArt.width) x \(pixelArt.height)"
    }
    
    private func updateBone() {
        print("Updating bone '\(bone.name)' with pixel art '\(pixelArt.name)'")
        let nonEmptyPixels = pixelArt.pixels.flatMap({ $0 }).compactMap({ $0 }).count
        print("Pixel art contains \(nonEmptyPixels) non-empty pixels out of \(pixelArt.width * pixelArt.height) total pixels")
        
        delegate?.pixelArtEditor(self, didUpdatePixelArt: pixelArt, for: bone)
        print("Delegate notified of pixel art update")
    }
    
    private func importImageToCanvas(_ image: NSImage) {
        // Get the image representation
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return
        }
        
        let imageWidth = bitmap.pixelsWide
        let imageHeight = bitmap.pixelsHigh
        
        // Resize pixel art to match image dimensions (with reasonable limits)
        let maxSize = 128
        let newWidth = min(imageWidth, maxSize)
        let newHeight = min(imageHeight, maxSize)
        

        
        // Resize the pixel art
        resizePixelArt(to: newWidth, height: newHeight)
        
        // Convert image pixels to pixel art
        for y in 0..<newHeight {
            for x in 0..<newWidth {
                // Calculate source coordinates (scale if needed)
                let sourceX = Int(Float(x) * Float(imageWidth) / Float(newWidth))
                let sourceY = Int(Float(y) * Float(imageHeight) / Float(newHeight))
                
                // Get pixel color from bitmap
                if let color = bitmap.colorAt(x: sourceX, y: sourceY) {
                    // Only set non-transparent pixels
                    if color.alphaComponent > 0.1 {
                        pixelArt.pixels[y][x] = color
                    }
                }
            }
        }
        
        // Update canvas view
        canvasView.pixelArt = pixelArt
        canvasView.needsDisplay = true
        
        // Update canvas view constraints to display full pixel art
        canvasView.removeFromSuperview()
        if let scrollView = canvasView.superview as? NSScrollView {
            scrollView.documentView = canvasView
        }
        
        // Update canvas size constraints
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.widthAnchor.constraint(equalToConstant: CGFloat(pixelArt.width * 16)),
            canvasView.heightAnchor.constraint(equalToConstant: CGFloat(pixelArt.height * 16))
        ])
         
         updateBone()
         updateDebugInfo()
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
    
}

// MARK: - ColorPaletteDelegate

extension PixelArtEditorWindow: ColorPaletteDelegate {
    func colorSelected(_ color: NSColor) {
        canvasView.currentColor = color
        updateCurrentColorView()
    }
}

// MARK: - PixelArtCanvasViewDelegate

extension PixelArtEditorWindow: PixelArtCanvasViewDelegate {
    func pixelArtCanvasDidChange(_ canvas: PixelArtCanvasView) {
        updateBone()
        updateCurrentColorView()
    }
    func pixelArtCanvasDidPickColor(_ canvas: PixelArtCanvasView, color: NSColor) {
        canvasView.currentColor = color
        updateCurrentColorView()
        colorPalette.selectColor(color)
    }
}