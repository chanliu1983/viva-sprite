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
            needsDisplay = true
        }
    }
    
    private var selectedJoint: Joint?
    private var selectedBone: Bone?
    private var isDragging = false
    private var dragOffset: simd_float2 = simd_float2(0, 0)
    private var isIKMode = false
    private var ikChain: [Joint] = []
    
    // Tool and canvas panning
    enum SkeletalTool {
        case select
        case move
        case addJointBone  // Unified mode for joint and bone creation
        case delete
    }
    
    var currentTool: SkeletalTool = .select
    private var canvasOffset: simd_float2 = simd_float2(0, 0)
    private var isPanning = false
    private var lastPanPoint: simd_float2 = simd_float2(0, 0)
    
    // Visual settings
    private let jointRadius: CGFloat = 8.0
    private let selectedJointRadius: CGFloat = 12.0
    
    // MARK: - First Responder
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    private let boneWidth: CGFloat = 4.0
    private let selectedBoneWidth: CGFloat = 6.0
    
    // Colors
    private let jointColor = NSColor.systemBlue
    private let selectedJointColor = NSColor.systemOrange
    private let fixedJointColor = NSColor.systemRed
    private let boneColor = NSColor.systemGray
    private let selectedBoneColor = NSColor.systemOrange
    private let ikChainColor = NSColor.systemGreen
    
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
        
        // Draw IK chain if in IK mode
        if isIKMode {
            drawIKChain(context: context)
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
            let isInIKChain = isIKMode && (ikChain.contains { $0.id == bone.startJoint.id } || ikChain.contains { $0.id == bone.endJoint.id })
            
            let color = isSelected ? selectedBoneColor : (isInIKChain ? ikChainColor : bone.color)
            let width = isSelected ? selectedBoneWidth : boneWidth
            
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
    
    private func drawJoints(context: CGContext, skeleton: Skeleton) {
        for joint in skeleton.joints {
            let worldPos = joint.worldPosition()
            let position = CGPoint(x: CGFloat(worldPos.x + canvasOffset.x), y: CGFloat(worldPos.y + canvasOffset.y))
            let isSelected = selectedJoint?.id == joint.id
            let isInIKChain = isIKMode && ikChain.contains { $0.id == joint.id }
            
            let radius = isSelected ? selectedJointRadius : jointRadius
            let color = joint.isFixed ? fixedJointColor : (isSelected ? selectedJointColor : (isInIKChain ? ikChainColor : jointColor))
            
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
            
            // Calculate pixel art position based on anchor point
            let pixelArtWidth = CGFloat(pixelArt.width * 2) // Scale up for visibility
            let pixelArtHeight = CGFloat(pixelArt.height * 2)
            
            let anchorOffset = simd_float2(
                (pixelArt.anchorPoint.x - 0.5) * Float(pixelArtWidth),
                (pixelArt.anchorPoint.y - 0.5) * Float(pixelArtHeight)
            )
            
            let rotatedOffset = rotateVector(anchorOffset, by: boneAngle)
            let pixelArtPos = boneCenter - rotatedOffset
            
            // Draw pixel art preview (simplified)
            context.saveGState()
            context.translateBy(x: CGFloat(pixelArtPos.x + canvasOffset.x), y: CGFloat(pixelArtPos.y + canvasOffset.y))
            context.rotate(by: CGFloat(boneAngle))
            
            // Draw a simple rectangle representing the pixel art
            let rect = CGRect(x: -pixelArtWidth/2, y: -pixelArtHeight/2, width: pixelArtWidth, height: pixelArtHeight)
            context.setFillColor(NSColor.systemPurple.withAlphaComponent(0.3).cgColor)
            context.setStrokeColor(NSColor.systemPurple.cgColor)
            context.setLineWidth(1.0)
            context.fill(rect)
            context.stroke(rect)
            
            context.restoreGState()
        }
    }
    
    private func drawIKChain(context: CGContext) {
        guard ikChain.count >= 2 else { return }
        
        // Only draw IK chain lines for joints that are NOT connected by bones
        // This prevents the dotted line from appearing over existing bones
        context.setStrokeColor(ikChainColor.cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [3, 3])
        
        for i in 0..<ikChain.count - 1 {
            let joint1 = ikChain[i]
            let joint2 = ikChain[i + 1]
            
            // Check if there's already a bone connecting these joints
            let hasBone = skeleton?.bones.contains { bone in
                (bone.startJoint === joint1 && bone.endJoint === joint2) ||
                (bone.startJoint === joint2 && bone.endJoint === joint1)
            } ?? false
            
            // Only draw dotted line if no bone exists between these joints
            if !hasBone {
                let startPos = joint1.worldPosition().cgPoint
                let endPos = joint2.worldPosition().cgPoint
                
                context.move(to: startPos)
                context.addLine(to: endPos)
            }
        }
        
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
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
                            if isIKMode, let selectedJoint = selectedJoint {
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
                if isIKMode, let selectedJoint = selectedJoint {
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
            
            if isIKMode {
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
        
        if isIKMode {
            // In IK mode, always use IK solving to maintain rigid bone lengths
            // Only proceed if we have a valid IK chain and the joint is not fixed
            if ikChain.count >= 2 && !joint.isFixed {
                let targetPosition = (worldPoint - canvasOffset) + dragOffset
                IKSolver.solveIK(chain: ikChain, target: targetPosition, skeleton: skeleton!)
                
                // Recursively resolve connected chains to maintain bone rigidity
                let modifiedJoints = Set(ikChain)
                resolveConnectedChains(skeleton: skeleton!, modifiedJoints: modifiedJoints)
                
                delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
            }
            // If joint is fixed or no valid chain, do nothing (maintain rigidity)
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
    
    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        
        switch key {
        case "s":
            currentTool = .select
        case "m":
            currentTool = .move
        case "a":
            currentTool = .addJointBone
        case "d":
            currentTool = .delete
        default:
            super.keyDown(with: event)
            return
        }
        
        // Update the tool selection in the parent controller
        if let parentController = findParentViewController() as? SkeletalDocumentViewController {
            parentController.updateToolSelection(for: currentTool)
        }
        
        needsDisplay = true
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
    
    private func buildIKChain(to targetJoint: Joint) {
        ikChain.removeAll()
        guard let skeleton = skeleton else { return }
        
        // Build chain with target joint at the END (required for IK solver)
        var visited = Set<Joint>()
        var chain = [Joint]()
        visited.insert(targetJoint)
        
        // First, extend backwards from target joint to find the root
        var current = targetJoint
        var backwardChain = [targetJoint]
        
        while let connectedJoint = findConnectedJoint(to: current, in: skeleton, excluding: visited) {
            backwardChain.insert(connectedJoint, at: 0)
            visited.insert(connectedJoint)
            current = connectedJoint
            if backwardChain.count >= 10 { break }
        }
        
        // The backward chain now has root at index 0 and target joint at the end
        chain = backwardChain
        
        // Optionally extend forward from target joint (but keep target at end)
        current = targetJoint
        var forwardExtension = [Joint]()
        
        while let connectedJoint = findConnectedJoint(to: current, in: skeleton, excluding: visited) {
            forwardExtension.append(connectedJoint)
            visited.insert(connectedJoint)
            current = connectedJoint
            if chain.count + forwardExtension.count >= 10 { break }
        }
        
        // If we found forward extensions, we need to choose the best chain
        // For IK to work correctly, we want the target joint at the END
        if !forwardExtension.isEmpty {
            // Use the forward extension as the main chain with target joint in the middle
            // But we need target at the end, so we'll use the backward chain instead
            // This ensures the selected joint is always the end effector
        }
        
        ikChain = chain
    }
    
    private func findConnectedJoint(to joint: Joint, in skeleton: Skeleton, excluding visited: Set<Joint>) -> Joint? {
        for bone in skeleton.bones {
            if bone.startJoint === joint && !visited.contains(bone.endJoint) {
                return bone.endJoint
            } else if bone.endJoint === joint && !visited.contains(bone.startJoint) {
                return bone.startJoint
            }
        }
        return nil
    }
    
    /// Recursively resolve IK for connected chains when joints are modified
    private func resolveConnectedChains(skeleton: Skeleton, modifiedJoints: Set<Joint>, depth: Int = 0) {
        // Prevent infinite recursion
        guard depth < 3 else { return }
        
        var newlyModifiedJoints = Set<Joint>()
        
        // Enforce bone lengths for all bones connected to modified joints
        for joint in modifiedJoints {
            let connectedBones = skeleton.bones.filter { bone in
                bone.startJoint === joint || bone.endJoint === joint
            }
            
            for bone in connectedBones {
                let currentLength = simd_distance(bone.startJoint.position, bone.endJoint.position)
                let expectedLength = bone.originalLength
                
                // Use a smaller tolerance to be more strict about bone lengths
                if abs(currentLength - expectedLength) > 0.1 {
                    // Determine which joint to move (prefer non-fixed joints not in IK chain)
                    let startInIKChain = ikChain.contains { $0 === bone.startJoint }
                    let endInIKChain = ikChain.contains { $0 === bone.endJoint }
                    
                    if !bone.endJoint.isFixed && !endInIKChain && (bone.startJoint.isFixed || startInIKChain || modifiedJoints.contains(bone.startJoint)) {
                        // Move end joint to maintain bone length
                        let direction = simd_normalize(bone.endJoint.position - bone.startJoint.position)
                        bone.endJoint.position = bone.startJoint.position + direction * expectedLength
                        newlyModifiedJoints.insert(bone.endJoint)
                    } else if !bone.startJoint.isFixed && !startInIKChain && (bone.endJoint.isFixed || endInIKChain || modifiedJoints.contains(bone.endJoint)) {
                        // Move start joint to maintain bone length
                        let direction = simd_normalize(bone.startJoint.position - bone.endJoint.position)
                        bone.startJoint.position = bone.endJoint.position + direction * expectedLength
                        newlyModifiedJoints.insert(bone.startJoint)
                    }
                }
            }
        }
        
        // Recursively resolve newly modified joints
        if !newlyModifiedJoints.isEmpty {
            resolveConnectedChains(skeleton: skeleton, modifiedJoints: newlyModifiedJoints, depth: depth + 1)
        }
    }
    
    /// Build an IK chain starting from a specific joint
    private func buildChainFrom(joint: Joint, skeleton: Skeleton) -> [Joint] {
        var chain = [joint]
        var visited = Set<Joint>()
        visited.insert(joint)
        var current = joint
        
        // Build chain by following bone connections
        while let connectedJoint = findConnectedJoint(to: current, in: skeleton, excluding: visited) {
            chain.append(connectedJoint)
            visited.insert(connectedJoint)
            current = connectedJoint
            
            // Limit chain length for performance
            if chain.count >= 5 {
                break
            }
        }
        
        return chain
    }
    
    private func openPixelArtEditor(for bone: Bone) {
        let pixelArtEditor = PixelArtEditorWindow(bone: bone)
        pixelArtEditor.delegate = self
        pixelArtEditor.showWindow(nil)
    }
    
    // MARK: - Public Methods
    
    func toggleIKMode() {
        isIKMode.toggle()
        if !isIKMode {
            ikChain.removeAll()
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
        }
        needsDisplay = true
    }
    
    func addJoint(at position: simd_float2, name: String) {
        guard let skeleton = skeleton else { return }
        
        let joint = Joint(name: name, position: position)
        skeleton.addJoint(joint)
        
        // Rebuild IK chain if in IK mode and we have a selected joint
        if isIKMode, let selectedJoint = selectedJoint {
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
        if isIKMode, let selectedJoint = selectedJoint {
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
            if isIKMode {
                ikChain.removeAll()
            }
        } else if let bone = selectedBone {
            skeleton.removeBone(bone)
            selectedBone = nil
            // Rebuild IK chain if in IK mode and we have a selected joint
            if isIKMode, let selectedJoint = selectedJoint {
                buildIKChain(to: selectedJoint)
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
        bone.pixelArt = pixelArt
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
        needsDisplay = true
    }
}