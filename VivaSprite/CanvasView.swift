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
        guard let image = NSImage(contentsOf: url) else {
            print("Failed to load image from \(url)")
            return
        }
        
        // Clear current canvas
        pixels = Array(repeating: Array(repeating: nil, count: gridSize), count: gridSize)
        
        // Create a bitmap representation of the image with proper aspect ratio
        let originalSize = image.size
        let scale = min(CGFloat(gridSize) / originalSize.width, CGFloat(gridSize) / originalSize.height)
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        
        // Center the image in the grid
        let offsetX = (CGFloat(gridSize) - scaledWidth) / 2
        let offsetY = (CGFloat(gridSize) - scaledHeight) / 2
        
        let targetSize = NSSize(width: gridSize, height: gridSize)
        let resizedImage = NSImage(size: targetSize)
        
        resizedImage.lockFocus()
        // Fill background with transparent/white
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: targetSize).fill()
        
        // Draw the image centered and scaled
        let drawRect = NSRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        image.draw(in: drawRect)
        resizedImage.unlockFocus()
        
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("Failed to create bitmap representation")
            return
        }
        
        // Convert bitmap to pixel grid
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                // NSBitmapImageRep has (0,0) at top-left, same as our pixel array
                let color = bitmapRep.colorAt(x: col, y: row)
                
                // Only set non-white pixels (preserve transparency)
                if let color = color, color != NSColor.white {
                    pixels[row][col] = color
                }
            }
        }
        
        // Mark document as clean after loading
        documentViewController?.markAsClean()
        
        // Refresh the view
        needsDisplay = true
    }
    
    func saveImage(to url: URL) {
        let imageSize = CGSize(width: CGFloat(gridSize), height: CGFloat(gridSize))
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        // Fill background with white
        NSColor.white.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        
        // Draw pixels
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                if let color = pixels[row][col] {
                    color.setFill()
                    let rect = NSRect(x: col, y: gridSize - 1 - row, width: 1, height: 1)
                    rect.fill()
                }
            }
        }
        
        image.unlockFocus()
        
        // Save as PNG
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
        }
    }
}