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
    
    // Visual settings
    private let jointRadius: CGFloat = 8.0
    private let selectedJointRadius: CGFloat = 12.0
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
    
    private func drawBones(context: CGContext, skeleton: Skeleton) {
        for bone in skeleton.bones {
            let startPos = bone.startJoint.worldPosition().cgPoint
            let endPos = bone.endJoint.worldPosition().cgPoint
            
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
            let position = joint.worldPosition().cgPoint
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
            context.translateBy(x: CGFloat(pixelArtPos.x), y: CGFloat(pixelArtPos.y))
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
        
        context.setStrokeColor(ikChainColor.cgColor)
        context.setLineWidth(3.0)
        context.setLineDash(phase: 0, lengths: [5, 5])
        
        for i in 0..<ikChain.count - 1 {
            let startPos = ikChain[i].worldPosition().cgPoint
            let endPos = ikChain[i + 1].worldPosition().cgPoint
            
            context.move(to: startPos)
            context.addLine(to: endPos)
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
        
        // Check for joint selection first
        if let joint = findJoint(at: worldPoint) {
            selectedJoint = joint
            selectedBone = nil
            delegate?.skeletalEditor(self, didSelectJoint: joint)
            
            if isIKMode {
                buildIKChain(to: joint)
            } else {
                isDragging = true
                dragOffset = joint.position - worldPoint
            }
        }
        // Then check for bone selection
        else if let bone = findBone(at: worldPoint) {
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
        guard isDragging, let joint = selectedJoint, !joint.isFixed else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        if isIKMode && ikChain.count >= 2 {
            // Perform IK solving
            IKSolver.solveIK(chain: ikChain, target: worldPoint)
            delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
        } else {
            // Direct manipulation
            joint.position = worldPoint + dragOffset
            delegate?.skeletalEditor(self, didModifySkeleton: skeleton!)
        }
        
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }
    
    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        if let joint = findJoint(at: worldPoint) {
            selectedJoint = joint
            needsDisplay = true
        }
        
        super.rightMouseDown(with: event)
    }
    
    // MARK: - Double Click Handling
    
    private func handleDoubleClick(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let worldPoint = simd_float2(Float(point.x), Float(point.y))
        
        if let bone = findBone(at: worldPoint) {
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
    
    private func buildIKChain(to endJoint: Joint) {
        ikChain.removeAll()
        
        var current: Joint? = endJoint
        while let joint = current {
            ikChain.insert(joint, at: 0)
            current = joint.parent
            
            // Limit chain length for performance
            if ikChain.count >= 10 {
                break
            }
        }
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
        }
        needsDisplay = true
    }
    
    func addJoint(at position: simd_float2, name: String) {
        guard let skeleton = skeleton else { return }
        
        let joint = Joint(name: name, position: position)
        skeleton.addJoint(joint)
        
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
        needsDisplay = true
    }
    
    func addBone(from startJoint: Joint, to endJoint: Joint, name: String) {
        guard let skeleton = skeleton else { return }
        
        let bone = Bone(name: name, start: startJoint, end: endJoint)
        skeleton.addBone(bone)
        
        // Establish parent-child relationship
        startJoint.addChild(endJoint)
        
        delegate?.skeletalEditor(self, didModifySkeleton: skeleton)
        needsDisplay = true
    }
    
    @objc func deleteSelected() {
        guard let skeleton = skeleton else { return }
        
        if let joint = selectedJoint {
            skeleton.removeJoint(joint)
            selectedJoint = nil
        } else if let bone = selectedBone {
            skeleton.removeBone(bone)
            selectedBone = nil
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