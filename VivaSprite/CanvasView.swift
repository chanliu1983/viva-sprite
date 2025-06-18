//
//  CanvasView.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

class CanvasView: NSView {
    
    var toolManager: ToolManager?
    weak var documentViewController: DocumentViewController?
    
    private let gridSize: Int = 32 // 32x32 pixel grid
    private let pixelSize: CGFloat = 16 // Each pixel is 16x16 points
    private var pixels: [[NSColor?]] = []
    private var isDrawing = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCanvas()
    }
    
    private func setupCanvas() {
        // Initialize pixel grid
        pixels = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        
        // Set up view properties
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        
        // Set frame size based on grid
        let canvasSize = CGFloat(gridSize) * pixelSize
        frame = NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)
        
        // Draw grid lines
        drawGrid(context: context)
        
        // Draw pixels
        drawPixels(context: context)
    }
    
    private func drawGrid(context: CGContext) {
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        
        // Vertical lines
        for i in 0...gridSize {
            let x = CGFloat(i) * pixelSize
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        
        // Horizontal lines
        for i in 0...gridSize {
            let y = CGFloat(i) * pixelSize
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        
        context.strokePath()
    }
    
    private func drawPixels(context: CGContext) {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if let color = pixels[row][col] {
                    context.setFillColor(color.cgColor)
                    let rect = CGRect(
                        x: CGFloat(col) * pixelSize + 1,
                        y: CGFloat(gridSize - 1 - row) * pixelSize + 1,
                        width: pixelSize - 2,
                        height: pixelSize - 2
                    )
                    context.fill(rect)
                }
            }
        }
    }
    
    private func pixelCoordinates(from point: NSPoint) -> (row: Int, col: Int)? {
        let col = Int(point.x / pixelSize)
        let row = gridSize - 1 - Int(point.y / pixelSize)
        
        guard row >= 0 && row < gridSize && col >= 0 && col < gridSize else {
            return nil
        }
        
        return (row, col)
    }
    
    private func drawPixel(at point: NSPoint) {
        guard let toolManager = toolManager,
              let coordinates = pixelCoordinates(from: point) else { return }
        
        let row = coordinates.row
        let col = coordinates.col
        
        switch toolManager.currentTool {
        case .pen:
            pixels[row][col] = toolManager.currentColor
        case .eraser:
            pixels[row][col] = nil
        }
        
        // Mark document as modified
        documentViewController?.markAsModified()
        
        // Redraw the affected pixel area
        let rect = CGRect(
            x: CGFloat(col) * pixelSize,
            y: CGFloat(gridSize - 1 - row) * pixelSize,
            width: pixelSize,
            height: pixelSize
        )
        setNeedsDisplay(rect)
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        isDrawing = true
        let point = convert(event.locationInWindow, from: nil)
        drawPixel(at: point)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isDrawing {
            let point = convert(event.locationInWindow, from: nil)
            drawPixel(at: point)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        isDrawing = false
    }
    
    // MARK: - Public Methods
    
    func clearCanvas() {
        pixels = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        documentViewController?.markAsModified()
        needsDisplay = true
    }
    
    func loadImage(from url: URL) {
        // Load image data directly
        guard let imageData = try? Data(contentsOf: url),
              let sourceRep = NSBitmapImageRep(data: imageData) else {
            print("Failed to load image from \(url)")
            return
        }
        
        // Clear current canvas
        pixels = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        
        // Get source dimensions
        let sourceWidth = sourceRep.pixelsWide
        let sourceHeight = sourceRep.pixelsHigh
        
        // Calculate scaling to fit within grid while maintaining aspect ratio
        let scaleX = Double(gridSize) / Double(sourceWidth)
        let scaleY = Double(gridSize) / Double(sourceHeight)
        let scale = min(scaleX, scaleY)
        
        // Calculate dimensions after scaling
        let targetWidth = Int(Double(sourceWidth) * scale)
        let targetHeight = Int(Double(sourceHeight) * scale)
        
        // Calculate offsets to center the image
        let offsetX = (gridSize - targetWidth) / 2
        let offsetY = (gridSize - targetHeight) / 2
        
        // Sample pixels from source and place in our grid
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                // Skip pixels outside the target area
                if row < offsetY || row >= offsetY + targetHeight || 
                   col < offsetX || col >= offsetX + targetWidth {
                    continue
                }
                
                // Map grid coordinates to source coordinates
                let sourceX = Int(Double(col - offsetX) / scale)
                let sourceY = Int(Double(row - offsetY) / scale)
                
                // Ensure source coordinates are within bounds
                if sourceX >= 0 && sourceX < sourceWidth && sourceY >= 0 && sourceY < sourceHeight {
                    // Get color from source (handle coordinate system differences)
                    guard let color = sourceRep.colorAt(x: sourceX, y: sourceY) else { continue }
                    
                    // Only set non-white/non-transparent pixels
                    if color.alphaComponent > 0.1 && color != NSColor.white {
                        pixels[row][col] = color.withAlphaComponent(1.0) // Strip alpha
                    }
                }
            }
        }
        
        // Mark document as clean after loading
        documentViewController?.markAsClean()
        
        // Refresh the view
        needsDisplay = true
    }
    
    func saveImage(to url: URL) {
        // Create a new image with the exact grid size
        let image = NSImage(size: NSSize(width: gridSize, height: gridSize))
        
        // Lock focus to draw on the image
        image.lockFocus()
        
        // Fill with white background
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: gridSize, height: gridSize).fill()
        
        // Draw each pixel
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if let color = pixels[row][col] {
                    color.setFill()
                    // Flip y-coordinate to match the drawing coordinate system
                    let rect = NSRect(x: col, y: gridSize - 1 - row, width: 1, height: 1)
                    rect.fill()
                }
            }
        }
        
        // End drawing
        image.unlockFocus()
        
        // Create bitmap representation with exact pixel dimensions
        guard let bitmapRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: gridSize, pixelsHigh: gridSize, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        
        // Draw the image to the bitmap rep
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(in: NSRect(x: 0, y: 0, width: gridSize, height: gridSize))
        NSGraphicsContext.restoreGraphicsState()
        
        // Save as PNG
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: url)
    }
}