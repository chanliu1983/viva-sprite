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
    case pan
    case picker // Add color picker tool
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
    var zoomFactor: CGFloat = 1.0 {
        didSet {
            updateCanvasSize()
            needsDisplay = true
        }
    }
    
    private let pixelSize: CGFloat = 16.0
    private var isDrawing = false
    private var lastDrawnPixel: (row: Int, col: Int)? = nil
    private var drawnPixelsInStroke: Set<String> = [] // Track pixels drawn in current stroke
    
    // Pan functionality
    private var isPanning = false
    private var lastPanPoint: NSPoint = NSPoint.zero
    
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
            width: CGFloat(pixelArt.width) * pixelSize * zoomFactor,
            height: CGFloat(pixelArt.height) * pixelSize * zoomFactor
        )
        
        setFrameSize(newSize)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let pixelArt = pixelArt else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background to white for better contrast
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)
        
        // Draw pixels with improved rendering
        drawPixels(context: context, pixelArt: pixelArt)
        
        // Draw grid (disabled for better clarity)
        // drawGrid(context: context, pixelArt: pixelArt)
    }
    
    private func drawTransparencyPattern(context: CGContext) {
        guard let pixelArt = pixelArt else { return }
        
        let scaledPixelSize = pixelSize * zoomFactor
        let checkerSize: CGFloat = scaledPixelSize / 2
        context.setFillColor(NSColor.lightGray.cgColor)
        
        for row in 0..<pixelArt.height {
            for col in 0..<pixelArt.width {
                let pixelRect = CGRect(
                    x: CGFloat(col) * scaledPixelSize,
                    y: CGFloat(pixelArt.height - 1 - row) * scaledPixelSize,
                    width: scaledPixelSize,
                    height: scaledPixelSize
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
        let scaledPixelSize = pixelSize * zoomFactor
        
        // Enable anti-aliasing for smoother rendering
        context.setShouldAntialias(true)
        context.interpolationQuality = .high
        
        for row in 0..<pixelArt.height {
            for col in 0..<pixelArt.width {
                guard let color = pixelArt.pixels[row][col] else {
                    // Draw transparent pixels as white background
                    context.setFillColor(NSColor.white.cgColor)
                    let rect = CGRect(
                        x: CGFloat(col) * scaledPixelSize,
                        y: CGFloat(pixelArt.height - 1 - row) * scaledPixelSize,
                        width: scaledPixelSize,
                        height: scaledPixelSize
                    )
                    context.fill(rect)
                    continue
                }
                
                context.setFillColor(color.cgColor)
                
                let rect = CGRect(
                    x: CGFloat(col) * scaledPixelSize,
                    y: CGFloat(pixelArt.height - 1 - row) * scaledPixelSize,
                    width: scaledPixelSize,
                    height: scaledPixelSize
                )
                
                context.fill(rect)
            }
        }
    }
    
    private func drawGrid(context: CGContext, pixelArt: PixelArtData) {
        context.setStrokeColor(NSColor.gray.cgColor)
        context.setLineWidth(0.5)
        
        let scaledPixelSize = pixelSize * zoomFactor
        
        // Vertical lines
        for i in 0...pixelArt.width {
            let x = CGFloat(i) * scaledPixelSize
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        
        // Horizontal lines
        for i in 0...pixelArt.height {
            let y = CGFloat(i) * scaledPixelSize
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        
        context.strokePath()
    }
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        switch currentTool {
        case .pan:
            isPanning = true
            lastPanPoint = point
        case .pen, .eraser:
            if let (row, col) = pixelCoordinates(from: point) {
                isDrawing = true
                lastDrawnPixel = (row, col)
                drawnPixelsInStroke.removeAll()
                
                switch currentTool {
                case .pen:
                    drawBrush(at: row, col: col, color: currentColor)
                case .eraser:
                    eraseBrush(at: row, col: col)
                case .pan:
                    break // Already handled above
                case .picker:
                    break // Not relevant here
                }
            }
        case .picker:
            if let (row, col) = pixelCoordinates(from: point), let pixelArt = pixelArt, let pickedColor = pixelArt.pixels[row][col] {
                currentColor = pickedColor
                delegate?.pixelArtCanvasDidPickColor?(self, color: pickedColor)
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        switch currentTool {
        case .pan:
            if isPanning {
                let deltaX = point.x - lastPanPoint.x
                let deltaY = point.y - lastPanPoint.y
                
                // Get the scroll view and adjust its document visible rect
                if let scrollView = enclosingScrollView {
                    let currentRect = scrollView.documentVisibleRect
                    let newRect = NSRect(
                        x: currentRect.origin.x - deltaX,
                        y: currentRect.origin.y - deltaY,
                        width: currentRect.width,
                        height: currentRect.height
                    )
                    scrollView.documentView?.scroll(newRect.origin)
                }
                
                lastPanPoint = point
            }
        case .pen, .eraser:
            guard isDrawing else { return }
            
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
                case .pan:
                    break // Already handled above
                case .picker:
                    break // Not relevant here
                }
            }
        case .picker:
            break // No dragging for picker
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDrawing = false
        isPanning = false
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
        
        let scaledPixelSize = pixelSize * zoomFactor
        let col = Int(point.x / scaledPixelSize)
        let row = pixelArt.height - 1 - Int(point.y / scaledPixelSize)
        
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
        } // All cases handled

    }
    
}

@objc protocol PixelArtCanvasViewDelegate: AnyObject {
    func pixelArtCanvasDidChange(_ canvas: PixelArtCanvasView)
    @objc optional func pixelArtCanvasDidPickColor(_ canvas: PixelArtCanvasView, color: NSColor)
}
