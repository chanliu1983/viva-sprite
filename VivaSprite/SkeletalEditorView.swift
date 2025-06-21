//
//  SkeletalEditorView.swift
//  VivaSprite
//
//  Skeletal Editor View for creating and manipulating bone structures
//

import Cocoa
import simd

protocol SkeletalEditorDelegate: AnyObject {
    func skeletalEditor(_ editor: SkeletalEditorView, didSelectBone bone: Bone?)
    func skeletalEditor(_ editor: SkeletalEditorView, didSelectJoint joint: Joint?)
    func skeletalEditor(_ editor: SkeletalEditorView, didModifySkeleton skeleton: Skeleton)
}

class SkeletalEditorView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: SkeletalEditorDelegate?
    var skeleton: Skeleton? {
        didSet {
            if let skeleton = skeleton {
                initializeJointBoneConnections(skeleton: skeleton)
            }
            needsDisplay = true
        }
    }
    
    private var selectedJoint: Joint?
    private var selectedBone: Bone?
    private var isDragging = false
    private var dragOffset: simd_float2 = simd_float2(0, 0)
    enum SkeletalMode: Int {
        case direct = 0
        case ik = 1
    }
    
    var currentMode: SkeletalMode = .direct

    private var ikBonePaths: [[Bone]] = [] // Store individual bone paths for debugging
    
    // Tool and canvas panning
    enum SkeletalTool: Int {
        case move = 0
        case select = 1
        case addJointBone = 2 // Unified mode for joint and bone creation
        case delete = 3
    }
    
    var currentTool: SkeletalTool = .select
    var canvasOffset: simd_float2 = simd_float2(0, 0)
    private var isPanning = false
    private var lastPanPoint: simd_float2 = simd_float2(0, 0)
    
    // Visual settings
    private let jointRadius: CGFloat = 8.0
    private let selectedJointRadius: CGFloat = 12.0
    
    // MARK: - First Responder
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard let characters = event.characters?.lowercased() else { return }
        
        let parentController = findParentViewController() as? SkeletalDocumentViewController

        switch characters {
        case "q":
            setMode(.direct)
            parentController?.updateModeSelection(for: .direct)
        case "w":
            setMode(.ik)
            parentController?.updateModeSelection(for: .ik)
        case "m":
            currentTool = .move
            parentController?.updateToolSelection(for: .move)
        case "s":
            currentTool = .select
            parentController?.updateToolSelection(for: .select)
        case "a":
            currentTool = .addJointBone
            parentController?.updateToolSelection(for: .addJointBone)
        case "d":
            currentTool = .delete
            parentController?.updateToolSelection(for: .delete)
        default:
            super.keyDown(with: event)
        }
    }
    private let boneWidth: CGFloat = 4.0
    private let selectedBoneWidth: CGFloat = 6.0
    
    // Colors
    private let jointColor = NSColor.systemBlue
    private let selectedJointColor = NSColor.systemOrange
    private let fixedJointColor = NSColor.systemRed
    private let boneColor = NSColor.systemGray
    private let selectedBoneColor = NSColor.systemOrange
    
    // MARK: - Initialization
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        // Add context menu
        menu = createContextMenu()
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let skeleton = skeleton else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fill(bounds)
        
        // Draw grid
        drawGrid(context: context)
        
        // Draw coordinate axes
        drawCoordinateAxes(context: context)
        
        // Draw bones first (so they appear behind joints)
        drawBones(context: context, skeleton: skeleton)
        
        // Draw pixel art attachments
        drawPixelArtAttachments(context: context, skeleton: skeleton)
        
        // Draw joints
        drawJoints(context: context, skeleton: skeleton)
        
        // Draw path list overlay if in IK mode
        if currentMode == .ik {
            drawPathList(context: context)
        }
    }
    
    private func drawGrid(context: CGContext) {
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(0.5)
        
        let gridSpacing: CGFloat = 20.0
        
        // Vertical lines
        var x: CGFloat = 0
        while x <= bounds.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: bounds.height))
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y <= bounds.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
            y += gridSpacing
        }
        
        context.strokePath()
    }
    
    private func drawCoordinateAxes(context: CGContext) {
        // Calculate origin position with canvas offset
        let originX = CGFloat(canvasOffset.x)
        let originY = CGFloat(canvasOffset.y)
        
        // Draw X and Y axes
        context.setStrokeColor(NSColor.systemRed.cgColor)
        context.setLineWidth(2.0)
        
        // X-axis (horizontal red line)
        context.move(to: CGPoint(x: 0, y: originY))
        context.addLine(to: CGPoint(x: bounds.width, y: originY))
        
        // Y-axis (vertical red line)
        context.move(to: CGPoint(x: originX, y: 0))
        context.addLine(to: CGPoint(x: originX, y: bounds.height))
        
        context.strokePath()
        
        // Draw origin marker (small circle)
        context.setFillColor(NSColor.systemRed.cgColor)
        let originRadius: CGFloat = 4.0
        let originRect = CGRect(
            x: originX - originRadius,
            y: originY - originRadius,
            width: originRadius * 2,
            height: originRadius * 2
        )
        context.fillEllipse(in: originRect)
        
        // Draw axis labels
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.systemRed
        ]
        
        // X-axis label
        if originY >= 20 && originY <= bounds.height - 20 {
            let xLabel = "X" as NSString
            let xLabelSize = xLabel.size(withAttributes: attributes)
            let xLabelRect = CGRect(
                x: bounds.width - xLabelSize.width - 10,
                y: originY - xLabelSize.height - 5,
                width: xLabelSize.width,
                height: xLabelSize.height
            )
            xLabel.draw(in: xLabelRect, withAttributes: attributes)
        }
        
        // Y-axis label
        if originX >= 20 && originX <= bounds.width - 20 {
            let yLabel = "Y" as NSString
            let yLabelSize = yLabel.size(withAttributes: attributes)
            let yLabelRect = CGRect(
                x: originX + 5,
                y: bounds.height - yLabelSize.height - 10,
                width: yLabelSize.width,
                height: yLabelSize.height
            )
            yLabel.draw(in: yLabelRect, withAttributes: attributes)
        }
        
        // Draw origin coordinates label
        let originLabel = "(0,0)" as NSString
        let originLabelSize = originLabel.size(withAttributes: attributes)
        let originLabelRect = CGRect(
            x: originX + 8,
            y: originY + 8,
            width: originLabelSize.width,
            height: originLabelSize.height
        )
        originLabel.draw(in: originLabelRect, withAttributes: attributes)
    }
    
    private func drawBones(context: CGContext, skeleton: Skeleton) {
        for bone in skeleton.bones {
            let startWorld = bone.startJoint.worldPosition()
            let endWorld = bone.endJoint.worldPosition()
            let startPos = CGPoint(x: CGFloat(startWorld.x + canvasOffset.x), y: CGFloat(startWorld.y + canvasOffset.y))
            let endPos = CGPoint(x: CGFloat(endWorld.x + canvasOffset.x), y: CGFloat(endWorld.y + canvasOffset.y))
            
            let isSelected = selectedBone?.id == bone.id
            let isInDisplayedPath: Bool = {
                if currentMode == .ik, let selected = selectedJoint, !ikBonePaths.isEmpty {
                    // Find the bone paths that start from the selected joint
                    for bonePath in ikBonePaths {
                        if let firstJoint = bonePath.first?.startJoint, firstJoint === selected || bonePath.first?.endJoint === selected {
                            if bonePath.contains(where: { $0.id == bone.id }) {
                                return true
                            }
                        }
                    }
                }
                return false
            }()
            let color: NSColor
            if isSelected {
                color = selectedBoneColor
            } else if isInDisplayedPath {
                color = NSColor.systemYellow
            } else {
                color = bone.color
            }
            let width = isSelected ? selectedBoneWidth : isInDisplayedPath ? boneWidth * 2 : boneWidth
            
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.setLineCap(.round)
            
            context.move(to: startPos)
            context.addLine(to: endPos)
            context.strokePath()
            
            // Draw bone name
            let midPoint = CGPoint(
                x: (startPos.x + endPos.x) / 2,
                y: (startPos.y + endPos.y) / 2
            )
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.labelColor
            ]
            
            let text = bone.name as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: midPoint.x - textSize.width / 2,
                y: midPoint.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
            

        }
    }
    
    private func drawPathList(context: CGContext) {
        guard !ikBonePaths.isEmpty else { return }
        
        let padding: CGFloat = 10
        let lineHeight: CGFloat = 20
        let backgroundColor = NSColor.black.withAlphaComponent(0.7)
        let textColor = NSColor.white
        
        // Calculate the height needed for all paths
        let totalHeight = CGFloat(ikBonePaths.count) * lineHeight + padding * 2
        
        // Draw background
        let backgroundRect = CGRect(
            x: 0,
            y: bounds.height - totalHeight,
            width: bounds.width,
            height: totalHeight
        )
        
        context.setFillColor(backgroundColor.cgColor)
        context.fill(backgroundRect)
        
        // Draw each path
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
            .foregroundColor: textColor
        ]
        
        for (pathIndex, bonePath) in ikBonePaths.enumerated() {
            // Convert bone path to joint path
            var jointNames: [String] = []
            var currentJoint: Joint?
            
            // Start from the selected joint (target joint)
            if let selected = selectedJoint {
                currentJoint = selected
                jointNames.append(currentJoint!.name)
                
                // Follow the bone path from the selected joint
                for bone in bonePath {
                    if let current = currentJoint,
                       let nextJoint = bone.connectedJoint(from: current) {
                        jointNames.append(nextJoint.name)
                        currentJoint = nextJoint
                    }
                }
            }
            
            let pathString = jointNames.joined(separator: " -> ")
            let displayText = pathString as NSString
            let textRect = CGRect(
                x: padding,
                y: bounds.height - totalHeight + padding + CGFloat(pathIndex) * lineHeight,
                width: bounds.width - padding * 2,
                height: lineHeight
            )
            
            displayText.draw(in: textRect, withAttributes: textAttributes)
        }
    }
    
    private func drawJoints(context: CGContext, skeleton: Skeleton) {
        for joint in skeleton.joints {
            let worldPos = joint.worldPosition()
            let position = CGPoint(x: CGFloat(worldPos.x + canvasOffset.x), y: CGFloat(worldPos.y + canvasOffset.y))
            let isSelected = selectedJoint?.id == joint.id
            let radius = isSelected ? selectedJointRadius : jointRadius
            let color: NSColor
            if joint.isFixed {
                color = fixedJointColor
            } else if isSelected {
                color = selectedJointColor
            } else {
                color = jointColor
            }
            
            context.setFillColor(color.cgColor)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.0)
            
            let rect = CGRect(
                x: position.x - radius,
                y: position.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
            
            // Draw fixed indicator dot
            if joint.isFixed {
                context.setFillColor(NSColor.white.cgColor)
                let dotRadius: CGFloat = radius * 0.3
                let dotRect = CGRect(
                    x: position.x - dotRadius,
                    y: position.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                context.fillEllipse(in: dotRect)
            }
            
            // Draw joint name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9),
                .foregroundColor: NSColor.labelColor
            ]
            
            let text = joint.name as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: position.x - textSize.width / 2,
                y: position.y + radius + 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private func drawPixelArtAttachments(context: CGContext, skeleton: Skeleton) {
        for bone in skeleton.bones {
            guard let pixelArt = bone.pixelArt else { continue }
            
            let startPos = bone.startJoint.worldPosition()
            let endPos = bone.endJoint.worldPosition()
            let boneCenter = (startPos + endPos) / 2
            let boneAngle = bone.angle
            let totalRotation = boneAngle + bone.pixelArtRotation
            
            // Calculate pixel art position based on anchor point
            let pixelArtWidth = CGFloat(pixelArt.width * 2) * CGFloat(bone.pixelArtScale)
            let pixelArtHeight = CGFloat(pixelArt.height * 2) * CGFloat(bone.pixelArtScale)
            
            let anchorOffset = simd_float2(
                (pixelArt.anchorPoint.x - 0.5) * Float(pixelArtWidth),
                (pixelArt.anchorPoint.y - 0.5) * Float(pixelArtHeight)
            )
            
            let rotatedOffset = rotateVector(anchorOffset, by: totalRotation)
            let pixelArtPos = boneCenter - rotatedOffset
            
            // Draw actual pixel art
            context.saveGState()
            context.translateBy(x: CGFloat(pixelArtPos.x + canvasOffset.x), y: CGFloat(pixelArtPos.y + canvasOffset.y))
            context.rotate(by: CGFloat(totalRotation))
            
            // Calculate pixel size for rendering
            let pixelSize = CGFloat(2) * CGFloat(bone.pixelArtScale) // 2x2 pixels for visibility, scaled
            let totalWidth = CGFloat(pixelArt.width) * pixelSize
            let totalHeight = CGFloat(pixelArt.height) * pixelSize
            
            // Draw each pixel
            for row in 0..<pixelArt.height {
                for col in 0..<pixelArt.width {
                    if let color = pixelArt.pixels[row][col] {
                        let pixelRect = CGRect(
                            x: CGFloat(col) * pixelSize - totalWidth/2,
                            y: CGFloat(pixelArt.height - 1 - row) * pixelSize - totalHeight/2, // Flip Y coordinate
                            width: pixelSize,
                            height: pixelSize
                        )
                        context.setFillColor(color.cgColor)
                        context.fill(pixelRect)
                    }
                }
            }
            
            // Draw border around pixel art
            let borderRect = CGRect(x: -totalWidth/2, y: -totalHeight/2, width: totalWidth, height: totalHeight)
            context.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(0.5)
            context.stroke(borderRect)
            
            context.restoreGState()
        }
    }
    

    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        // Handle double click first
        if event.clickCount == 2 {
            handleDoubleClick(with: event)
            return
        }
        
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        // Handle move tool for canvas panning
        if currentTool == .move {
            isPanning = true
            lastPanPoint = worldPoint
            return
        }
        
        // Handle unified add joint/bone tool
        if currentTool == .addJointBone {
            guard let skeleton = skeleton else { return }
            let adjustedPoint = worldPoint - canvasOffset
            
            if let clickedJoint = findJoint(at: adjustedPoint) {
                if let startJoint = selectedJoint {
                    if startJoint.id == clickedJoint.id {
                        // Clicking the same joint again - deselect
                        selectedJoint = nil
                        selectedBone = nil
                        delegate?.skeletalEditor(self, didSelectJoint: nil)
                        delegate?.skeletalEditor(self, didSelectBone: nil)
                    } else {
                        // Clicking a different joint - create bone and deselect both
                        let existingBone = skeleton.bones.first { bone in
                            (bone.startJoint.id == startJoint.id && bone.endJoint.id == clickedJoint.id) ||
                            (bone.startJoint.id == clickedJoint.id && bone.endJoint.id == startJoint.id)
                        }
                        
                        if existingBone == nil {
                            // When creating bones in IK mode, use current distance as original length
                            // since joints might be displaced from their rest positions
                            let currentDistance = simd_distance(startJoint.position, clickedJoint.position)
                            let newBone = Bone(name: skeleton.boneName(from: startJoint, to: clickedJoint), 
                                             start: startJoint, end: clickedJoint, 
                                             originalLength: currentDistance)
                            skeleton.addBone(newBone)
                            
                            // Rebuild IK chain if in IK mode and we have a selected joint
                            if currentMode == .ik, let selectedJoint = selectedJoint {
                                buildIKChain(to: selectedJoint)
                            }
                            
                            delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
                        }
                        
                        // Deselect both joints after bone creation
                        selectedJoint = nil
                        selectedBone = nil
                        delegate?.skeletalEditor(self, didSelectJoint: nil)
                        delegate?.skeletalEditor(self, didSelectBone: nil)
                    }
                } else {
                    // No joint selected - select this joint
                    selectedJoint = clickedJoint
                    selectedBone = nil
                    delegate?.skeletalEditor(self, didSelectJoint: clickedJoint)
                }
            } else {
                // Clicked on empty space - create new joint
                let newJoint = Joint(name: skeleton.nextJointName(), position: adjustedPoint)
                skeleton.addJoint(newJoint)
                
                // Rebuild IK chain if in IK mode and we have a selected joint
                if currentMode == .ik, let selectedJoint = selectedJoint {
                    buildIKChain(to: selectedJoint)
                }
                
                selectedJoint = nil
                selectedBone = nil
                delegate?.skeletalEditor(self, didSelectJoint: nil)
                delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
            }
            
            needsDisplay = true
            return
        }

        
        // Handle delete tool
        if currentTool == .delete {
            guard let skeleton = skeleton else { return }
            let adjustedPoint = worldPoint - canvasOffset
            
            // Try to delete a joint first
            if let joint = findJoint(at: adjustedPoint) {
                // Remove all bones connected to this joint
                let bonesToRemove = skeleton.bones.filter { bone in
                    return bone.startJoint === joint || bone.endJoint === joint
                }
                for bone in bonesToRemove {
                    skeleton.removeBone(bone)
                }
                
                // Remove the joint
                skeleton.removeJoint(joint)
                selectedJoint = nil
                selectedBone = nil
                delegate?.skeletalEditor(self, didSelectJoint: nil)
                delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
                needsDisplay = true
                return
            }
            
            // Try to delete a bone
            if let bone = findBone(at: adjustedPoint) {
                skeleton.removeBone(bone)
                selectedBone = nil
                delegate?.skeletalEditor(self, didSelectBone: nil)
                delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
                needsDisplay = true
                return
            }
        }
        
        // Check for joint selection first
        if let joint = findJoint(at: worldPoint - canvasOffset) {
            selectedJoint = joint
            selectedBone = nil
            delegate?.skeletalEditor(self, didSelectJoint: joint)
            
            if currentMode == .ik {
                buildIKChain(to: joint)
                isDragging = true
                dragOffset = joint.position - (worldPoint - canvasOffset)
            } else {
                isDragging = true
                dragOffset = joint.position - (worldPoint - canvasOffset)
            }
        }
        // Then check for bone selection
        else if let bone = findBone(at: worldPoint - canvasOffset) {
            selectedBone = bone
            selectedJoint = nil
            delegate?.skeletalEditor(self, didSelectBone: bone)
        }
        // Clear selection
        else {
            selectedJoint = nil
            selectedBone = nil
            delegate?.skeletalEditor(self, didSelectJoint: nil)
            delegate?.skeletalEditor(self, didSelectBone: nil)
        }
        
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        // Handle canvas panning with move tool
        if isPanning && currentTool == .move {
            let delta = worldPoint - lastPanPoint
            canvasOffset += delta
            lastPanPoint = worldPoint
            needsDisplay = true
            return
        }
        guard isDragging, let joint = selectedJoint else { return }
        if currentMode == .ik {
            // In IK mode, use global iterative constraint solver
            if !joint.isFixed {
                let targetPosition = (worldPoint - canvasOffset) + dragOffset
                solveIKGlobalConstraints(movedJoint: joint, targetPosition: targetPosition)
                delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
            }
        } else {
            // Direct manipulation only in non-IK mode
            if !joint.isFixed {
                joint.position = (worldPoint - canvasOffset) + dragOffset
                delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
            }
        }
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        isPanning = false
    }
    
    private func findParentViewController() -> NSViewController? {
        var responder = self.nextResponder
        while responder != nil {
            if let viewController = responder as? NSViewController {
                return viewController
            }
            responder = responder?.nextResponder
        }
        return nil
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        if let joint = findJoint(at: worldPoint - canvasOffset) {
            selectedJoint = joint
            needsDisplay = true
            
            // Show context menu
            let menu = createContextMenu()
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }
    
    // MARK: - Double Click Handling
    
    private func handleDoubleClick(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        // Adjust for canvas offset like other mouse handling methods
        let adjustedPoint = worldPoint - canvasOffset
        
        if let bone = findBone(at: adjustedPoint) {
            openPixelArtEditor(for: bone)
        }
    }
    
    // MARK: - Helper Methods
    
    private func findJoint(at point: simd_float2) -> Joint? {
        guard let skeleton = skeleton else { return nil }
        
        for joint in skeleton.joints {
            let distance = simd_distance(joint.worldPosition(), point)
            if distance <= Float(jointRadius + 5) {
                return joint
            }
        }
        
        return nil
    }
    
    private func findBone(at point: simd_float2) -> Bone? {
        guard let skeleton = skeleton else { return nil }
        
        for bone in skeleton.bones {
            let startPos = bone.startJoint.worldPosition()
            let endPos = bone.endJoint.worldPosition()
            
            let distance = distanceFromPointToLine(point: point, lineStart: startPos, lineEnd: endPos)
            if distance <= Float(boneWidth + 5) {
                return bone
            }
        }
        
        return nil
    }
    
    private func distanceFromPointToLine(point: simd_float2, lineStart: simd_float2, lineEnd: simd_float2) -> Float {
        let lineVec = lineEnd - lineStart
        let pointVec = point - lineStart
        
        let lineLength = simd_length(lineVec)
        if lineLength == 0 {
            return simd_distance(point, lineStart)
        }
        
        let t = max(0, min(1, simd_dot(pointVec, lineVec) / (lineLength * lineLength)))
        let projection = lineStart + t * lineVec
        
        return simd_distance(point, projection)
    }

    private func exploreBones(from joint: Joint, 
                             currentBonePath: [Bone], 
                             visitedBones: Set<Bone>, 
                             allBonePaths: inout [[Bone]], 
                             skeleton: Skeleton) {
        
        // Get all bones connected to this joint
        let connectedBones = joint.getConnectedBones()
        
        // Check if there are any unvisited bones from this joint
        let unvisitedBones = connectedBones.filter { !visitedBones.contains($0) }
        
        if unvisitedBones.isEmpty {
            // This is an endpoint - no more unvisited bones to explore
            // Add the current bone path if it has at least one bone
            if !currentBonePath.isEmpty {
                allBonePaths.append(currentBonePath)
            }
            return
        }
        
        // Explore each unvisited connected bone
        for bone in unvisitedBones {
            // No need to check if visited since we already filtered for unvisited bones
            
            // Get the other joint of this bone
            let otherJoint = (bone.startJoint === joint) ? bone.endJoint : bone.startJoint
            
            // Create new bone path with this bone
            var newBonePath = currentBonePath
            newBonePath.append(bone)
            
            var newVisitedBones = visitedBones
            newVisitedBones.insert(bone)
            
            // If this joint is fixed, end the path here
            if otherJoint.isFixed {
                allBonePaths.append(newBonePath)
            } else {
                // Continue exploring from this joint (recursively explore its bones)
                exploreBones(from: otherJoint, 
                           currentBonePath: newBonePath, 
                           visitedBones: newVisitedBones, 
                           allBonePaths: &allBonePaths, 
                           skeleton: skeleton)
            }
        }
    }
    
    private func buildIKChain(to targetJoint: Joint) {
        ikBonePaths.removeAll()
        guard let skeleton = skeleton else { return }
        
        // Build multiple bone paths from the target joint using bone-based exploration
        // Each path explores bones connected to joints until reaching:
        // 1. A fixed joint, or
        // 2. An endpoint (joint with no further bone connections)
        var allBonePaths: [[Bone]] = []
        
        // Start bone exploration from the target joint
        exploreBones(from: targetJoint, 
                    currentBonePath: [], 
                    visitedBones: Set<Bone>(), 
                    allBonePaths: &allBonePaths, 
                    skeleton: skeleton)
        
        // Convert bone paths to joint paths for compatibility with existing IK solver
        var allJointPaths: [[Joint]] = []
        for bonePath in allBonePaths {
            if !bonePath.isEmpty {
                var jointPath: [Joint] = [targetJoint]
                var currentJoint = targetJoint
                
                for bone in bonePath {
                    let nextJoint = bone.connectedJoint(from: currentJoint)
                    
                    if nextJoint != nil {
                        currentJoint = nextJoint!
                        jointPath.append(currentJoint)
                    }
                }
                allJointPaths.append(jointPath)
            }
        }
        
        ikBonePaths = allBonePaths
        
        // All paths are now stored in ikBonePaths for visualization
        // Only include joints that are actually part of valid IK paths
        var combinedChain = Set<Joint>()
        
        for path in allJointPaths {
            for joint in path {
                combinedChain.insert(joint)
            }
        }
        

    }
    
    /// Propagate movement along a path, preserving bone lengths and not moving fixed joints
    private func propagateMovementAlongPath(path: [Joint], startPosition: simd_float2, skeleton: Skeleton) {
        guard path.count > 1 else { return }
        var currentPosition = startPosition
        path[0].position = currentPosition
        for i in 1..<path.count {
            let prevJoint = path[i-1]
            let joint = path[i]
            // Find the bone connecting these joints
            if let bone = skeleton.bones.first(where: { b in (b.startJoint === prevJoint && b.endJoint === joint) || (b.startJoint === joint && b.endJoint === prevJoint) }) {
                let direction = simd_normalize(joint.position - prevJoint.position)
                // If this joint is fixed, stop propagation
                if joint.isFixed { break }
                currentPosition = currentPosition + direction * bone.originalLength
                joint.position = currentPosition
            }
        }
    }

    /// Solve IK using a global iterative constraint solver (matches Python reference)
    private func solveIKGlobalConstraints(movedJoint: Joint, targetPosition: simd_float2, maxIterations: Int = 10) {
        guard let skeleton = skeleton else { return }
        // Step 1: Move the dragged joint to the target position
        movedJoint.position = targetPosition
        
        // Step 2: Iteratively enforce all bone length constraints
        let tolerance: Float = 0.1
        for _ in 0..<maxIterations {
            var anyMoved = false
            for bone in skeleton.bones {
                let j1 = bone.startJoint
                let j2 = bone.endJoint
                let currentLength = simd_distance(j1.position, j2.position)
                let targetLength = bone.originalLength
                if abs(currentLength - targetLength) < tolerance { continue }
                let dir = j2.position - j1.position
                if simd_length(dir) == 0 { continue }
                let normDir = simd_normalize(dir)
                let lengthError = currentLength - targetLength
                let j1CanMove = !j1.isFixed
                let j2CanMove = !j2.isFixed
                if j1CanMove && j2CanMove {
                    // Both can move: split correction
                    let correction = lengthError * 0.5
                    j1.position += normDir * correction
                    j2.position -= normDir * correction
                    anyMoved = true
                } else if j1CanMove {
                    j1.position += normDir * lengthError
                    anyMoved = true
                } else if j2CanMove {
                    j2.position -= normDir * lengthError
                    anyMoved = true
                }
            }
            if !anyMoved { break }
        }
        needsDisplay = true
    }
    

    

    

    
    /// Initialize joint-bone connections for existing skeletons
    private func initializeJointBoneConnections(skeleton: Skeleton) {
        // Clear all existing connections
        for joint in skeleton.joints {
            joint.connectedBones.removeAll()
        }
        
        // Rebuild connections from bones
        for bone in skeleton.bones {
            if !bone.startJoint.connectedBones.contains(where: { $0.id == bone.id }) {
                bone.startJoint.connectedBones.append(bone)
            }
            if !bone.endJoint.connectedBones.contains(where: { $0.id == bone.id }) {
                bone.endJoint.connectedBones.append(bone)
            }
        }
    }
    

    

    

    
    private var pixelArtEditorWindow: PixelArtEditorWindow?
    
    private func openPixelArtEditor(for bone: Bone) {
        let pixelArtEditor = PixelArtEditorWindow(bone: bone)
        pixelArtEditor.delegate = self
        self.pixelArtEditorWindow = pixelArtEditor // Retain reference
        
        // Present as sheet to maintain proper window hierarchy and event routing
        if let parentWindow = self.window {
            parentWindow.beginSheet(pixelArtEditor.window!) { [weak self] response in
                // Sheet completed
                self?.pixelArtEditorWindow = nil // Release reference when done
            }
        } else {
            // Fallback to regular window if no parent window
            pixelArtEditor.showWindow(nil)
            pixelArtEditor.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    // MARK: - Public Methods
    
        func setMode(_ mode: SkeletalMode) {
        currentMode = mode
        if currentMode == .direct {
            ikBonePaths.removeAll()
        } else {
            // When entering IK mode, update all bone original lengths to current lengths
            // This ensures that any changes made in Direct mode are preserved
            if let skeleton = skeleton {
                for bone in skeleton.bones {
                    bone.originalLength = bone.length
                }
            }
            
            // When entering IK mode, switch to select tool
            currentTool = .select
            if let parentController = findParentViewController() as? SkeletalDocumentViewController {
                parentController.updateToolSelection(for: currentTool)
            }
            
            // Clear IK data when entering IK mode
            if selectedJoint == nil {
                ikBonePaths.removeAll()
            } else if let selectedJoint = selectedJoint {
                buildIKChain(to: selectedJoint)
            }
        }
        needsDisplay = true
    }
    
    func exportAsImage() -> NSImage? {
        guard let skeleton = skeleton else { return nil }
        
        // Step 1: Calculate the bounding box of all pixel art attachments
        var boundingBox: CGRect? = nil
        
        for bone in skeleton.bones {
            guard let pixelArt = bone.pixelArt else { continue }
            
            let startPos = bone.startJoint.worldPosition()
            let endPos = bone.endJoint.worldPosition()
            let boneCenter = (startPos + endPos) / 2
            let boneAngle = bone.angle
            let totalRotation = boneAngle + bone.pixelArtRotation
            
            // Apply pixelArtScale to the pixel art dimensions for bounding box calculation
            let pixelArtWidth = CGFloat(pixelArt.width * 2) * CGFloat(bone.pixelArtScale)
            let pixelArtHeight = CGFloat(pixelArt.height * 2) * CGFloat(bone.pixelArtScale)
            
            let anchorOffset = simd_float2(
                (pixelArt.anchorPoint.x - 0.5) * Float(pixelArtWidth),
                (pixelArt.anchorPoint.y - 0.5) * Float(pixelArtHeight)
            )
            
            let rotatedOffset = rotateVector(anchorOffset, by: totalRotation)
            let pixelArtPos = boneCenter - rotatedOffset
            
            let transform = CGAffineTransform(translationX: CGFloat(pixelArtPos.x), y: CGFloat(pixelArtPos.y)).rotated(by: CGFloat(totalRotation))
            
            let corners = [
                CGPoint(x: -pixelArtWidth / 2, y: -pixelArtHeight / 2),
                CGPoint(x: pixelArtWidth / 2, y: -pixelArtHeight / 2),
                CGPoint(x: pixelArtWidth / 2, y: pixelArtHeight / 2),
                CGPoint(x: -pixelArtWidth / 2, y: pixelArtHeight / 2)
            ].map { $0.applying(transform) }
            
            for corner in corners {
                if boundingBox == nil {
                    boundingBox = CGRect(origin: corner, size: .zero)
                } else {
                    boundingBox = boundingBox!.union(CGRect(origin: corner, size: .zero))
                }
            }
        }
        
        guard let finalBoundingBox = boundingBox else {
            // No pixel art to export
            return nil
        }
        
        // Step 2: Create an NSImage and draw the pixel art
        let image = NSImage(size: finalBoundingBox.size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        
        // Translate the context so the drawing is within the image bounds
        context.translateBy(x: -finalBoundingBox.origin.x, y: -finalBoundingBox.origin.y)
        
        // Draw each pixel art attachment
        for bone in skeleton.bones {
            guard let pixelArt = bone.pixelArt else { continue }
            
            let startPos = bone.startJoint.worldPosition()
            let endPos = bone.endJoint.worldPosition()
            let boneCenter = (startPos + endPos) / 2
            let boneAngle = bone.angle
            let totalRotation = boneAngle + bone.pixelArtRotation
            
            // Apply pixelArtScale to the pixel art dimensions
            let pixelArtWidth = CGFloat(pixelArt.width * 2) * CGFloat(bone.pixelArtScale)
            let pixelArtHeight = CGFloat(pixelArt.height * 2) * CGFloat(bone.pixelArtScale)
            
            let anchorOffset = simd_float2(
                (pixelArt.anchorPoint.x - 0.5) * Float(pixelArtWidth),
                (pixelArt.anchorPoint.y - 0.5) * Float(pixelArtHeight)
            )
            
            let rotatedOffset = rotateVector(anchorOffset, by: totalRotation)
            let pixelArtPos = boneCenter - rotatedOffset
            
            context.saveGState()
            context.translateBy(x: CGFloat(pixelArtPos.x), y: CGFloat(pixelArtPos.y))
            context.rotate(by: CGFloat(totalRotation))
            
            // Apply pixelArtScale to the pixel size
            let pixelSize = CGFloat(2) * CGFloat(bone.pixelArtScale)
            let totalWidth = CGFloat(pixelArt.width) * pixelSize
            let totalHeight = CGFloat(pixelArt.height) * pixelSize
            
            for row in 0..<pixelArt.height {
                for col in 0..<pixelArt.width {
                    if let color = pixelArt.pixels[row][col] {
                        let pixelRect = CGRect(
                            x: CGFloat(col) * pixelSize - totalWidth / 2,
                            y: CGFloat(pixelArt.height - 1 - row) * pixelSize - totalHeight / 2,
                            width: pixelSize,
                            height: pixelSize
                        )
                        context.setFillColor(color.cgColor)
                        context.fill(pixelRect)
                    }
                }
            }
            
            context.restoreGState()
        }
        
        image.unlockFocus()
        return image
    }
    
    func addJoint(at position: simd_float2, name: String) {
        guard let skeleton = skeleton else { return }
        
        let joint = Joint(name: name, position: position)
        skeleton.addJoint(joint)
        
        // Rebuild IK chain if in IK mode and we have a selected joint
        if currentMode == .ik, let selectedJoint = selectedJoint {
            buildIKChain(to: selectedJoint)
        }
        
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
        needsDisplay = true
    }
    
    func addBone(from startJoint: Joint, to endJoint: Joint, name: String) {
        guard let skeleton = skeleton else { return }
        
        // Use current distance as original length since joints might be displaced in IK mode
        let currentDistance = simd_distance(startJoint.position, endJoint.position)
        let bone = Bone(name: name, start: startJoint, end: endJoint, originalLength: currentDistance)
        skeleton.addBone(bone)
        
        // Rebuild IK chain if in IK mode and we have a selected joint
        if currentMode == .ik, let selectedJoint = selectedJoint {
            buildIKChain(to: selectedJoint)
        }
        
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
        needsDisplay = true
    }
    
    @objc func deleteSelected() {
        guard let skeleton = skeleton else { return }
        
        if let joint = selectedJoint {
            skeleton.removeJoint(joint)
            selectedJoint = nil
            // Clear IK chain since selected joint was deleted
            if currentMode == .ik {
                ikBonePaths.removeAll()
            }
        } else if let bone = selectedBone {
            skeleton.removeBone(bone)
            selectedBone = nil
            // Rebuild IK chain if in IK mode
            if currentMode == .ik {
                if let selectedJoint = selectedJoint {
                    buildIKChain(to: selectedJoint)
                } else {
                    // If no joint is selected, clear the IK paths
                    ikBonePaths.removeAll()
                }
            }
        }
        
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
        needsDisplay = true
    }
    
    // MARK: - Context Menu
    
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        let addJointItem = NSMenuItem(title: "Add Joint", action: #selector(addJointAtCursor), keyEquivalent: "")
        addJointItem.target = self
        menu.addItem(addJointItem)
        
        let toggleFixedItem = NSMenuItem(title: "Toggle Fixed", action: #selector(toggleJointFixed), keyEquivalent: "")
        toggleFixedItem.target = self
        menu.addItem(toggleFixedItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteSelected), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)
        
        return menu
    }
    
    @objc private func addJointAtCursor() {
        guard let event = NSApp.currentEvent else { return }
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        let name = "Joint \(skeleton?.joints.count ?? 0 + 1)"
        addJoint(at: worldPoint, name: name)
    }
    
    @objc private func toggleJointFixed() {
        guard let joint = selectedJoint else { return }
        joint.isFixed.toggle()
        needsDisplay = true
    }
}

// MARK: - PixelArtEditorWindow Delegate

extension SkeletalEditorView: PixelArtEditorDelegate {
    func pixelArtEditor(_ editor: PixelArtEditorWindow, didUpdatePixelArt pixelArt: PixelArtData, for bone: Bone) {
        print("SkeletalEditorView: Received pixel art update for bone '\(bone.name)'")
        let nonEmptyPixels = pixelArt.pixels.flatMap({ $0 }).compactMap({ $0 }).count
        print("SkeletalEditorView: Pixel art has \(nonEmptyPixels) non-empty pixels")
        
        bone.pixelArt = pixelArt
        print("SkeletalEditorView: Assigned pixel art to bone.pixelArt")
        
        if let skeleton = skeleton {
            // Add or update pixel art in skeleton.pixelArts
            if let idx = skeleton.pixelArts.firstIndex(where: { $0.id == pixelArt.id }) {
                skeleton.pixelArts[idx] = pixelArt
                print("SkeletalEditorView: Updated existing pixel art in skeleton.pixelArts at index \(idx)")
            } else {
                skeleton.addPixelArt(pixelArt)
                print("SkeletalEditorView: Added new pixel art to skeleton.pixelArts")
            }
        }
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
        needsDisplay = true
        print("SkeletalEditorView: Triggered display update to show pixel art on bone")
    }
}
