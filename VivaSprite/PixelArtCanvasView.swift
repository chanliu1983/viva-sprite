//
//  PixelArtCanvasView.swift
//  VivaSprite
//
//  Canvas view for editing pixel art in the dedicated editor window
//

import Cocoa

enum PixelArtTool {
    case pen
    case eraser
    case fill
}

class PixelArtCanvasView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: PixelArtCanvasViewDelegate?
    
    var pixelArt: PixelArtData? {
        didSet {
            updateCanvasSize()
            needsDisplay = true
        }
    }
    
    var currentTool: PixelArtTool = .pen
    var currentColor: NSColor = .black
    
    private let pixelSize: CGFloat = 16.0
    private var isDrawing = false
    private var lastDrawnPixel: (row: Int, col: Int)? = nil
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
    }
    
    private func updateCanvasSize() {
        guard let pixelArt = pixelArt else { return }
        
        let newSize = NSSize(
            width: CGFloat(pixelArt.width) * pixelSize,
            height: CGFloat(pixelArt.height) * pixelSize
        )
        
        setFrameSize(newSize)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let pixelArt = pixelArt else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)
        
        // Draw checkerboard pattern for transparency
        drawTransparencyPattern(context: context)
        
        // Draw pixels
        drawPixels(context: context, pixelArt: pixelArt)
        
        // Draw grid
        drawGrid(context: context, pixelArt: pixelArt)
    }
    
    private func drawTransparencyPattern(context: CGContext) {
        guard let pixelArt = pixelArt else { return }
        
        let checkerSize: CGFloat = pixelSize / 2
        context.setFillColor(NSColor.lightGray.cgColor)
        
        for row in 0..<pixelArt.height {
            for col in 0..<pixelArt.width {
                let pixelRect = CGRect(
                    x: CGFloat(col) * pixelSize,
                    y: CGFloat(pixelArt.height - 1 - row) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                
                // Draw checkerboard pattern
                for i in 0..<2 {
                    for j in 0..<2 {
                        if (i + j) % 2 == 1 {
                            let checkerRect = CGRect(
                                x: pixelRect.minX + CGFloat(i) * checkerSize,
                                y: pixelRect.minY + CGFloat(j) * checkerSize,
                                width: checkerSize,
                                height: checkerSize
                            )
                            context.fill(checkerRect)
                        }
                    }
                }
            }
        }
    }
    
    private func drawPixels(context: CGContext, pixelArt: PixelArtData) {
        for row in 0..<pixelArt.height {
            for col in 0..<pixelArt.width {
                guard let color = pixelArt.pixels[row][col] else { continue }
                
                context.setFillColor(color.cgColor)
                
                let rect = CGRect(
                    x: CGFloat(col) * pixelSize + 1,
                    y: CGFloat(pixelArt.height - 1 - row) * pixelSize + 1,
                    width: pixelSize - 2,
                    height: pixelSize - 2
                )
                
                context.fill(rect)
            }
        }
    }
    
    private func drawGrid(context: CGContext, pixelArt: PixelArtData) {
        context.setStrokeColor(NSColor.gray.cgColor)
        context.setLineWidth(0.5)
        
        // Vertical lines
        for i in 0...pixelArt.width {
            let x = CGFloat(i) * pixelSize
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        
        // Horizontal lines
        for i in 0...pixelArt.height {
            let y = CGFloat(i) * pixelSize
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        
        context.strokePath()
    }
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if let (row, col) = pixelCoordinates(from: point) {
            isDrawing = true
            lastDrawnPixel = (row, col)
            
            switch currentTool {
            case .pen:
                drawPixel(at: row, col: col, color: currentColor)
            case .eraser:
                erasePixel(at: row, col: col)
            case .fill:
                floodFill(at: row, col: col, with: currentColor)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        
        if let (row, col) = pixelCoordinates(from: point) {
            // Avoid redrawing the same pixel
            if let last = lastDrawnPixel, last.row == row && last.col == col {
                return
            }
            
            lastDrawnPixel = (row, col)
            
            switch currentTool {
            case .pen:
                drawPixel(at: row, col: col, color: currentColor)
            case .eraser:
                erasePixel(at: row, col: col)
            case .fill:
                // Fill tool doesn't work with dragging
                break
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDrawing = false
        lastDrawnPixel = nil
    }
    
    // MARK: - Drawing Operations
    
    private func drawPixel(at row: Int, col: Int, color: NSColor) {
        guard var pixelArt = pixelArt else { return }
        guard row >= 0 && row < pixelArt.height && col >= 0 && col < pixelArt.width else { return }
        
        pixelArt.pixels[row][col] = color
        self.pixelArt = pixelArt
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    private func erasePixel(at row: Int, col: Int) {
        guard var pixelArt = pixelArt else { return }
        guard row >= 0 && row < pixelArt.height && col >= 0 && col < pixelArt.width else { return }
        
        pixelArt.pixels[row][col] = nil
        self.pixelArt = pixelArt
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    private func floodFill(at row: Int, col: Int, with color: NSColor) {
        guard var pixelArt = pixelArt else { return }
        guard row >= 0 && row < pixelArt.height && col >= 0 && col < pixelArt.width else { return }
        
        let targetColor = pixelArt.pixels[row][col]
        
        // Don't fill if the target color is the same as the fill color
        if colorsEqual(targetColor, color) {
            return
        }
        
        var stack: [(Int, Int)] = [(row, col)]
        var visited: Set<String> = []
        
        while !stack.isEmpty {
            let (currentRow, currentCol) = stack.removeLast()
            let key = "\(currentRow),\(currentCol)"
            
            if visited.contains(key) {
                continue
            }
            
            if currentRow < 0 || currentRow >= pixelArt.height || currentCol < 0 || currentCol >= pixelArt.width {
                continue
            }
            
            if !colorsEqual(pixelArt.pixels[currentRow][currentCol], targetColor!) {
                continue
            }
            
            visited.insert(key)
            pixelArt.pixels[currentRow][currentCol] = color
            
            // Add neighboring pixels
            stack.append((currentRow - 1, currentCol)) // Up
            stack.append((currentRow + 1, currentCol)) // Down
            stack.append((currentRow, currentCol - 1)) // Left
            stack.append((currentRow, currentCol + 1)) // Right
        }
        
        self.pixelArt = pixelArt
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    private func colorsEqual(_ color1: NSColor?, _ color2: NSColor) -> Bool {
        guard let color1 = color1 else { return false }
        
        let rgb1 = color1.usingColorSpace(.deviceRGB)
        let rgb2 = color2.usingColorSpace(.deviceRGB)
        
        guard let rgb1 = rgb1, let rgb2 = rgb2 else { return false }
        
        return abs(rgb1.redComponent - rgb2.redComponent) < 0.001 &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < 0.001 &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < 0.001 &&
               abs(rgb1.alphaComponent - rgb2.alphaComponent) < 0.001
    }
    
    // MARK: - Helper Methods
    
    private func pixelCoordinates(from point: NSPoint) -> (row: Int, col: Int)? {
        guard let pixelArt = pixelArt else { return nil }
        
        let col = Int(point.x / pixelSize)
        let row = pixelArt.height - 1 - Int(point.y / pixelSize)
        
        guard row >= 0 && row < pixelArt.height && col >= 0 && col < pixelArt.width else {
            return nil
        }
        
        return (row, col)
    }
    
    // MARK: - Public Methods
    
    func clearCanvas() {
        guard var pixelArt = pixelArt else { return }
        
        for row in 0..<pixelArt.height {
            for col in 0..<pixelArt.width {
                pixelArt.pixels[row][col] = nil
            }
        }
        
        self.pixelArt = pixelArt
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    func setPixel(at row: Int, col: Int, color: NSColor?) {
        guard var pixelArt = pixelArt else { return }
        guard row >= 0 && row < pixelArt.height && col >= 0 && col < pixelArt.width else { return }
        
        pixelArt.pixels[row][col] = color
        self.pixelArt = pixelArt
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    func getPixel(at row: Int, col: Int) -> NSColor? {
        guard let pixelArt = pixelArt else { return nil }
        guard row >= 0 && row < pixelArt.height && col >= 0 && col < pixelArt.width else { return nil }
        
        return pixelArt.pixels[row][col]
    }
    
    // MARK: - Keyboard Handling
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51: // Delete key
            if let (row, col) = lastDrawnPixel {
                erasePixel(at: row, col: col)
            }
        case 36: // Return key
            // Could be used for confirming operations
            break
        default:
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Undo/Redo Support
    
    private var undoStack: [[[NSColor?]]] = []
    private var redoStack: [[[NSColor?]]] = []
    private let maxUndoSteps = 50
    
    func saveUndoState() {
        guard let pixelArt = pixelArt else { return }
        
        // Deep copy the current state
        let currentState = pixelArt.pixels.map { row in
            row.map { $0 }
        }
        
        undoStack.append(currentState)
        
        // Limit undo stack size
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
    }
    
    func undo() {
        guard var pixelArt = pixelArt, !undoStack.isEmpty else { return }
        
        // Save current state to redo stack
        let currentState = pixelArt.pixels.map { row in
            row.map { $0 }
        }
        redoStack.append(currentState)
        
        // Restore previous state
        let previousState = undoStack.removeLast()
        pixelArt.pixels = previousState
        self.pixelArt = pixelArt
        
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    func redo() {
        guard var pixelArt = pixelArt, !redoStack.isEmpty else { return }
        
        // Save current state to undo stack
        let currentState = pixelArt.pixels.map { row in
            row.map { $0 }
        }
        undoStack.append(currentState)
        
        // Restore next state
        let nextState = redoStack.removeLast()
        pixelArt.pixels = nextState
        self.pixelArt = pixelArt
        
        needsDisplay = true
        delegate?.pixelArtCanvasDidChange(self)
    }
    
    var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        return !redoStack.isEmpty
    }
}
