//
//  ToolManager.swift
//  VivaSprite
//
//  Created on 2024
//

import Cocoa

enum DrawingTool {
    case pen
    case eraser
}

class ToolManager {
    
    var currentTool: DrawingTool = .pen
    var currentColor: NSColor = .black
    var brushSize: Int = 1
    
    init() {
        // Default settings
    }
    
    func setTool(_ tool: DrawingTool) {
        currentTool = tool
    }
    
    func setColor(_ color: NSColor) {
        currentColor = color
    }
    
    func setBrushSize(_ size: Int) {
        brushSize = max(1, min(size, 5)) // Limit brush size between 1 and 5
    }
    
    var toolName: String {
        switch currentTool {
        case .pen:
            return "Pen"
        case .eraser:
            return "Eraser"
        }
    }
    
    var isErasing: Bool {
        return currentTool == .eraser
    }
}