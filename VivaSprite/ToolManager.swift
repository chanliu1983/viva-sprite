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
}