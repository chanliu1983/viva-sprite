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
}

class PixelArtCanvasView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: PixelArtCanvasViewDelegate?
    
    var pixelArt: PixelArtData? {
        didSet {
            if let pixelArt = pixelArt {
                print("PixelArtCanvasView: Pixel art assigned - \(pixelArt.name), size: \(pixelArt.width)x\(pixelArt.height)")
                let nonEmptyPixels = pixelArt.pixels.flatMap({ $0 }).compactMap({ $0 }).count
                print("PixelArtCanvasView: Non-empty pixels count: \(nonEmptyPixels)")
            } else {
                print("PixelArtCanvasView: Pixel art set to nil")
            }
            updateCanvasSize()
            needsDisplay = true
        }
    }
    
    var currentTool: PixelArtTool = .pen
    var currentColor: NSColor = .black
    var brushSize: Int = 1 // Brush size from 1 to 5 pixels
    
    private let pixelSize: CGFloat = 16.0
    private var isDrawing = false
    private var lastDrawnPixel: (row: Int, col: Int)? = nil
    private var drawnPixelsInStroke: Set<String> = [] // Track pixels drawn in current stroke
    
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
            drawnPixelsInStroke.removeAll()
            
            switch currentTool {
            case .pen:
                drawBrush(at: row, col: col, color: currentColor)
            case .eraser:
                eraseBrush(at: row, col: col)
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
                drawBrush(at: row, col: col, color: currentColor)
            case .eraser:
                eraseBrush(at: row, col: col)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDrawing = false
        lastDrawnPixel = nil
        drawnPixelsInStroke.removeAll()
    }
    
    // MARK: - Drawing Operations
    
    private func drawBrush(at row: Int, col: Int, color: NSColor) {
        guard var pixelArt = pixelArt else { return }
        
        var pixelsChanged = false
        let halfSize = brushSize / 2
        
        for r in (row - halfSize)...(row + halfSize) {
            for c in (col - halfSize)...(col + halfSize) {
                let pixelKey = "\(r),\(c)"
                
                // Skip if already drawn in this stroke
                if drawnPixelsInStroke.contains(pixelKey) {
                    continue
                }
                
                // Check bounds
                if r >= 0 && r < pixelArt.height && c >= 0 && c < pixelArt.width {
                    pixelArt.pixels[r][c] = color
                    drawnPixelsInStroke.insert(pixelKey)
                    pixelsChanged = true
                }
            }
        }
        
        if pixelsChanged {
            self.pixelArt = pixelArt
            needsDisplay = true
            delegate?.pixelArtCanvasDidChange(self)
        }
    }
    
    private func eraseBrush(at row: Int, col: Int) {
        guard var pixelArt = pixelArt else { return }
        
        var pixelsChanged = false
        let halfSize = brushSize / 2
        
        for r in (row - halfSize)...(row + halfSize) {
            for c in (col - halfSize)...(col + halfSize) {
                let pixelKey = "\(r),\(c)"
                
                // Skip if already drawn in this stroke
                if drawnPixelsInStroke.contains(pixelKey) {
                    continue
                }
                
                // Check bounds
                if r >= 0 && r < pixelArt.height && c >= 0 && c < pixelArt.width {
                    pixelArt.pixels[r][c] = nil
                    drawnPixelsInStroke.insert(pixelKey)
                    pixelsChanged = true
                }
            }
        }
        
        if pixelsChanged {
            self.pixelArt = pixelArt
            needsDisplay = true
            delegate?.pixelArtCanvasDidChange(self)
        }
    }
    
    private func drawPixel(at row: Int, col: Int, color: NSColor) {
        print("[DEBUG] drawPixel called at row: \(row), col: \(col), color: \(color)")
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
