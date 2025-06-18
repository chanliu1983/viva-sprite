//
//  ColorPalette.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

protocol ColorPaletteDelegate: AnyObject {
    func colorSelected(_ color: NSColor)
}

class ColorPalette: NSView {
    
    weak var delegate: ColorPaletteDelegate?
    
    private let colors: [NSColor] = [
        .black, .white, .red, .green, .blue, .yellow, .orange, .purple,
        .brown, .gray, .lightGray, .darkGray, .cyan, .magenta,
        NSColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0), // Pink
        NSColor(red: 0.5, green: 0.8, blue: 0.5, alpha: 1.0), // Light Green
        NSColor(red: 0.8, green: 0.8, blue: 0.5, alpha: 1.0), // Light Yellow
        NSColor(red: 0.5, green: 0.5, blue: 0.8, alpha: 1.0), // Light Blue
        NSColor(red: 0.8, green: 0.5, blue: 0.5, alpha: 1.0), // Light Red
        NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0), // Dark Brown
        NSColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1.0), // Dark Blue
        NSColor(red: 0.4, green: 0.6, blue: 0.2, alpha: 1.0), // Dark Green
        NSColor(red: 0.6, green: 0.2, blue: 0.4, alpha: 1.0), // Dark Red
        NSColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0)  // Dark Purple
    ]
    
    private var selectedColorIndex: Int = 0
    private let colorSize: CGFloat = 24
    private let spacing: CGFloat = 4
    private let colorsPerRow: Int = 8
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupPalette()
    }
    
    private func setupPalette() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8
        
        // Calculate required size
        let rows = (colors.count + colorsPerRow - 1) / colorsPerRow
        let width = CGFloat(colorsPerRow) * (colorSize + spacing) - spacing + 16
        let height = CGFloat(rows) * (colorSize + spacing) - spacing + 16
        
        frame = NSRect(x: 0, y: 0, width: width, height: height)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw color swatches
        for (index, color) in colors.enumerated() {
            let row = index / colorsPerRow
            let col = index % colorsPerRow
            
            let x = CGFloat(col) * (colorSize + spacing) + 8
            let y = bounds.height - CGFloat(row + 1) * (colorSize + spacing) - 8 + spacing
            
            let rect = CGRect(x: x, y: y, width: colorSize, height: colorSize)
            
            // Draw color
            context.setFillColor(color.cgColor)
            context.fill(rect)
            
            // Draw border
            if index == selectedColorIndex {
                context.setStrokeColor(NSColor.controlAccentColor.cgColor)
                context.setLineWidth(3)
            } else {
                context.setStrokeColor(NSColor.separatorColor.cgColor)
                context.setLineWidth(1)
            }
            context.stroke(rect)
        }
    }
    
    private func colorIndex(at point: NSPoint) -> Int? {
        for (index, _) in colors.enumerated() {
            let row = index / colorsPerRow
            let col = index % colorsPerRow
            
            let x = CGFloat(col) * (colorSize + spacing) + 8
            let y = bounds.height - CGFloat(row + 1) * (colorSize + spacing) - 8 + spacing
            
            let rect = CGRect(x: x, y: y, width: colorSize, height: colorSize)
            
            if rect.contains(point) {
                return index
            }
        }
        return nil
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if let index = colorIndex(at: point) {
            selectedColorIndex = index
            delegate?.colorSelected(colors[index])
            needsDisplay = true
        }
    }
    
    // MARK: - Public Methods
    
    func selectColor(_ color: NSColor) {
        if let index = colors.firstIndex(of: color) {
            selectedColorIndex = index
            needsDisplay = true
        }
    }
    
    var selectedColor: NSColor {
        return colors[selectedColorIndex]
    }
}