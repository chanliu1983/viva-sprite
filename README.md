# VivaSprite - Pixel Art Editor

A simple and intuitive pixel art editor built for macOS using Swift and Cocoa.

## Features

### Drawing Tools
- **Pen Tool**: Draw pixels with the selected color
- **Eraser Tool**: Remove pixels from the canvas
- Easy tool switching with segmented control

### Canvas
- 32x32 pixel grid for creating pixel art
- Visual grid lines for precise pixel placement
- Zoom-friendly interface with clear pixel boundaries
- Mouse-based drawing with click and drag support

### Color Palette
- 24 predefined colors including:
  - Basic colors (black, white, red, green, blue, etc.)
  - Pastel variations
  - Dark variations
- Visual color selection with highlighted active color
- Easy color switching with mouse clicks

### File Operations
- **New**: Clear the canvas to start fresh (⌘N)
- **Save**: Export your pixel art as PNG image (⌘S)
- File picker integration for easy saving

## How to Use

1. **Select a Tool**: Choose between Pen and Eraser using the segmented control
2. **Pick a Color**: Click on any color in the palette to select it
3. **Draw**: Click and drag on the canvas to draw pixels
4. **Save Your Work**: Use File > Save or ⌘S to export as PNG
5. **Start Over**: Use File > New or ⌘N to clear the canvas

## Technical Details

- **Platform**: macOS 13.0+
- **Language**: Swift 5.0
- **Framework**: Cocoa/AppKit
- **Architecture**: MVC pattern with custom views

### Project Structure

- `AppDelegate.swift`: Application lifecycle management
- `ViewController.swift`: Main controller coordinating UI components
- `CanvasView.swift`: Custom view handling pixel drawing and mouse events
- `ColorPalette.swift`: Custom view for color selection
- `ToolManager.swift`: State management for drawing tools and properties
- `Main.storyboard`: Interface Builder layout

## Building the Project

1. Open `VivaSprite.xcodeproj` in Xcode
2. Select the VivaSprite scheme
3. Build and run (⌘R)

Or build from command line:
```bash
xcodebuild -project VivaSprite.xcodeproj -scheme VivaSprite -destination platform=macOS build
```

## Features in Detail

### Canvas Implementation
- Uses Core Graphics for efficient pixel rendering
- Grid overlay for visual guidance
- Coordinate transformation for proper pixel mapping
- Optimized redraw regions for smooth performance

### Color Management
- Delegate pattern for color selection communication
- Visual feedback for selected colors
- Extensible color palette system

### Tool System
- Enum-based tool representation
- State management through ToolManager
- Easy extension for additional tools

## Future Enhancements

Potential features that could be added:
- Brush size options
- Additional tools (fill bucket, line tool, rectangle tool)
- Undo/Redo functionality
- Custom color picker
- Layer support
- Animation frames
- Different canvas sizes
- Import existing images

## License

This project is created as a demonstration of macOS app development with Swift.