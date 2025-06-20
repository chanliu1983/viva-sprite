//
//  SkeletalDocumentViewController.swift
//  VivaSprite
//
//  Document view controller for skeletal animation projects
//

import Cocoa
import simd

class SkeletalDocumentViewController: NSViewController {
    
    // MARK: - UI Elements
    
    var skeletalEditorView: SkeletalEditorView!
    var toolPopUpButton: NSPopUpButton!
    var modeSegmentedControl: NSSegmentedControl!
  private var propertiesStackView: NSStackView!
    
    // MARK: - Properties
    
    var skeleton: Skeleton!
    var documentName: String = "Untitled Skeleton"
    var isModified: Bool = false {
        didSet {
            updateTabTitle()
        }
    }
    
    weak var tabViewController: TabViewController?
    
    private var selectedJoint: Joint?
    private var selectedBone: Bone?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSkeleton()
        setupUI()
        setupProperties()
        
        // Configure skeletal editor after UI is set up
        skeletalEditorView.skeleton = skeleton
        skeletalEditorView.delegate = self
        
        // Set initial tool to Move mode
        skeletalEditorView.currentTool = .move
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Make the skeletal editor view the first responder to receive keyboard events
        view.window?.makeFirstResponder(skeletalEditorView)
    }
    
    // MARK: - Setup
    
    private func setupSkeleton() {
        skeleton = Skeleton(name: documentName)
    }
    
    private func createDefaultSkeleton() {
        // Create root joint
        let root = Joint(name: "Root", position: simd_float2(400, 300))
        root.isFixed = true
        skeleton.addJoint(root)
        
        // Create torso
        let torso = Joint(name: "Torso", position: simd_float2(400, 350))
        skeleton.addJoint(torso)
        
        let spine = Bone(name: "Spine", start: root, end: torso)
        skeleton.addBone(spine)
        
        // Create head
        let head = Joint(name: "Head", position: simd_float2(400, 400))
        skeleton.addJoint(head)
        
        let neck = Bone(name: "Neck", start: torso, end: head)
        skeleton.addBone(neck)
        
        // Create left arm
        let leftShoulder = Joint(name: "Left Shoulder", position: simd_float2(370, 340))
        skeleton.addJoint(leftShoulder)
        
        let leftUpperArm = Bone(name: "Left Upper Arm", start: torso, end: leftShoulder)
        skeleton.addBone(leftUpperArm)
        
        let leftElbow = Joint(name: "Left Elbow", position: simd_float2(340, 320))
        skeleton.addJoint(leftElbow)
        
        let leftForearm = Bone(name: "Left Forearm", start: leftShoulder, end: leftElbow)
        skeleton.addBone(leftForearm)
        
        let leftHand = Joint(name: "Left Hand", position: simd_float2(310, 300))
        skeleton.addJoint(leftHand)
        
        let leftHand_bone = Bone(name: "Left Hand", start: leftElbow, end: leftHand)
        skeleton.addBone(leftHand_bone)
        
        // Create right arm (mirrored)
        let rightShoulder = Joint(name: "Right Shoulder", position: simd_float2(430, 340))
        skeleton.addJoint(rightShoulder)
        
        let rightUpperArm = Bone(name: "Right Upper Arm", start: torso, end: rightShoulder)
        skeleton.addBone(rightUpperArm)
        
        let rightElbow = Joint(name: "Right Elbow", position: simd_float2(460, 320))
        skeleton.addJoint(rightElbow)
        
        let rightForearm = Bone(name: "Right Forearm", start: rightShoulder, end: rightElbow)
        skeleton.addBone(rightForearm)
        
        let rightHand = Joint(name: "Right Hand", position: simd_float2(490, 300))
        skeleton.addJoint(rightHand)
        
        let rightHand_bone = Bone(name: "Right Hand", start: rightElbow, end: rightHand)
        skeleton.addBone(rightHand_bone)
        
        // Create legs
        let leftHip = Joint(name: "Left Hip", position: simd_float2(385, 280))
        skeleton.addJoint(leftHip)
        
        let leftThigh = Bone(name: "Left Thigh", start: root, end: leftHip)
        skeleton.addBone(leftThigh)
        
        let leftKnee = Joint(name: "Left Knee", position: simd_float2(380, 220))
        skeleton.addJoint(leftKnee)
        
        let leftShin = Bone(name: "Left Shin", start: leftHip, end: leftKnee)
        skeleton.addBone(leftShin)
        
        let leftFoot = Joint(name: "Left Foot", position: simd_float2(375, 160))
        skeleton.addJoint(leftFoot)
        
        let leftFoot_bone = Bone(name: "Left Foot", start: leftKnee, end: leftFoot)
        skeleton.addBone(leftFoot_bone)
        
        // Right leg (mirrored)
        let rightHip = Joint(name: "Right Hip", position: simd_float2(415, 280))
        skeleton.addJoint(rightHip)
        
        let rightThigh = Bone(name: "Right Thigh", start: root, end: rightHip)
        skeleton.addBone(rightThigh)
        
        let rightKnee = Joint(name: "Right Knee", position: simd_float2(420, 220))
        skeleton.addJoint(rightKnee)
        
        let rightShin = Bone(name: "Right Shin", start: rightHip, end: rightKnee)
        skeleton.addBone(rightShin)
        
        let rightFoot = Joint(name: "Right Foot", position: simd_float2(425, 160))
        skeleton.addJoint(rightFoot)
        
        let rightFoot_bone = Bone(name: "Right Foot", start: rightKnee, end: rightFoot)
        skeleton.addBone(rightFoot_bone)
    }
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Create main split view
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)
        
        // Create left panel
        let leftPanel = NSView()
        leftPanel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create right panel with skeletal editor
        let rightPanel = NSView()
        rightPanel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create skeletal editor view
        skeletalEditorView = SkeletalEditorView()
        skeletalEditorView.translatesAutoresizingMaskIntoConstraints = false
        rightPanel.addSubview(skeletalEditorView)
        
        // Create left panel stack view
        let leftStackView = NSStackView()
        leftStackView.orientation = .vertical
        leftStackView.alignment = .leading
        leftStackView.spacing = 8
        leftStackView.translatesAutoresizingMaskIntoConstraints = false
        leftPanel.addSubview(leftStackView)
        
        // Create tools section
        let toolsLabel = NSTextField(labelWithString: "Tools")
        toolsLabel.font = NSFont.boldSystemFont(ofSize: 14)
        leftStackView.addArrangedSubview(toolsLabel)
        
        // Setup tool control
        toolPopUpButton = NSPopUpButton()
        toolPopUpButton.addItem(withTitle: "Move")
        toolPopUpButton.addItem(withTitle: "Select")
        toolPopUpButton.addItem(withTitle: "Add")
        toolPopUpButton.addItem(withTitle: "Delete")
        toolPopUpButton.selectItem(at: 0)
        toolPopUpButton.target = self
        toolPopUpButton.action = #selector(toolChanged(_:))
        leftStackView.addArrangedSubview(toolPopUpButton)
        
        // Create mode section
        let modeLabel = NSTextField(labelWithString: "Mode")
        modeLabel.font = NSFont.boldSystemFont(ofSize: 14)
        leftStackView.addArrangedSubview(modeLabel)
        
        // Setup mode control
        modeSegmentedControl = NSSegmentedControl()
        modeSegmentedControl.segmentCount = 2
        modeSegmentedControl.setLabel("Direct", forSegment: 0)
        modeSegmentedControl.setLabel("IK", forSegment: 1)
        modeSegmentedControl.selectedSegment = 0
        modeSegmentedControl.target = self
        modeSegmentedControl.action = #selector(modeChanged(_:))
        leftStackView.addArrangedSubview(modeSegmentedControl)
        

        
        // Create properties section
        let propertiesLabel = NSTextField(labelWithString: "Properties")
        propertiesLabel.font = NSFont.boldSystemFont(ofSize: 14)
        leftStackView.addArrangedSubview(propertiesLabel)
        
        // Create properties scroll view
        let propertiesScrollView = NSScrollView()
        propertiesScrollView.borderType = .bezelBorder
        propertiesScrollView.hasVerticalScroller = true
        propertiesScrollView.autohidesScrollers = true
        
        propertiesStackView = NSStackView()
        propertiesStackView.orientation = .vertical
        propertiesStackView.alignment = .leading
        propertiesStackView.distribution = .fill
        propertiesStackView.spacing = 8
        propertiesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        propertiesScrollView.documentView = propertiesStackView
        
        // Ensure the stack view fills the scroll view width
        NSLayoutConstraint.activate([
            propertiesStackView.leadingAnchor.constraint(equalTo: propertiesScrollView.leadingAnchor),
            propertiesStackView.trailingAnchor.constraint(equalTo: propertiesScrollView.trailingAnchor),
            propertiesStackView.topAnchor.constraint(equalTo: propertiesScrollView.topAnchor),
            propertiesStackView.widthAnchor.constraint(equalTo: propertiesScrollView.widthAnchor)
        ])
        leftStackView.addArrangedSubview(propertiesScrollView)
        
        // Add panels to split view
        splitView.addArrangedSubview(leftPanel)
        splitView.addArrangedSubview(rightPanel)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Split view constraints
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Left panel constraints
            leftPanel.widthAnchor.constraint(equalToConstant: 350),
            leftStackView.topAnchor.constraint(equalTo: leftPanel.topAnchor, constant: 8),
            leftStackView.leadingAnchor.constraint(equalTo: leftPanel.leadingAnchor, constant: 8),
            leftStackView.trailingAnchor.constraint(equalTo: leftPanel.trailingAnchor, constant: -8),
            leftStackView.bottomAnchor.constraint(equalTo: leftPanel.bottomAnchor, constant: -8),
            
            // Skeletal editor constraints
            skeletalEditorView.topAnchor.constraint(equalTo: rightPanel.topAnchor),
            skeletalEditorView.leadingAnchor.constraint(equalTo: rightPanel.leadingAnchor),
            skeletalEditorView.trailingAnchor.constraint(equalTo: rightPanel.trailingAnchor),
            skeletalEditorView.bottomAnchor.constraint(equalTo: rightPanel.bottomAnchor),
            
            // Tool control width
            toolPopUpButton.widthAnchor.constraint(equalToConstant: 334),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 334),
            
            // Scroll view heights
            propertiesScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        // Set split view position
        splitView.setPosition(350, ofDividerAt: 0)
    }
    

    
    private func setupProperties() {
        // Properties panel will be populated based on selection
        updatePropertiesPanel()
    }
    
    // MARK: - Actions
    
    @objc func toolChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0:
            skeletalEditorView.currentTool = .move
        case 1:
            skeletalEditorView.currentTool = .select
        case 2:
            skeletalEditorView.currentTool = .addJointBone
        case 3:
            skeletalEditorView.currentTool = .delete
        default:
            skeletalEditorView.currentTool = .move
        }
    }
    
    @objc func modeChanged(_ sender: NSSegmentedControl) {
        skeletalEditorView.toggleIKMode()
    }
    
    func updateToolSelection(for tool: SkeletalEditorView.SkeletalTool) {
        switch tool {
        case .move:
            toolPopUpButton.selectItem(at: 0)
        case .select:
            toolPopUpButton.selectItem(at: 1)
        case .addJointBone:
            toolPopUpButton.selectItem(at: 2)
        case .delete:
            toolPopUpButton.selectItem(at: 3)
        }
    }
    
    @objc func addJoint(_ sender: Any) {
        let center = skeletalEditorView.bounds.center
        let worldPoint = simd_float2(Float(center.x), Float(center.y))
        let name = "Joint \(skeleton.joints.count + 1)"
        skeletalEditorView.addJoint(at: worldPoint, name: name)
    }
    
    @objc func deleteSelected(_ sender: Any) {
        skeletalEditorView.deleteSelected()
    }
    
    @objc func exportSkeleton(_ sender: Any) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(documentName).json"
        
        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            exportSkeletonToJSON(url: url)
        }
    }
    
    @objc func importSkeleton(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.urls.first else { return }
            importSkeletonFromJSON(url: url)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateTabTitle() {
        let title = isModified ? "\(documentName) •" : documentName
        tabViewController?.updateTabTitle(for: self, title: title)
    }
    
    private func updatePropertiesPanel() {
        // Clear existing properties
        propertiesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if let joint = selectedJoint {
            setupJointProperties(joint)
        } else if let bone = selectedBone {
            setupBoneProperties(bone)
        }
        // When nothing is selected, leave the properties panel empty
    }
    
    private func setupJointProperties(_ joint: Joint) {
        let titleLabel = NSTextField(labelWithString: "Joint Properties")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        propertiesStackView.addArrangedSubview(titleLabel)
        
        // Name
        let nameContainer = createPropertyRow(label: "Name:", control: {
            let textField = NSTextField()
            textField.stringValue = joint.name
            textField.target = self
            textField.action = #selector(jointNameChanged(_:))
            return textField
        }())
        propertiesStackView.addArrangedSubview(nameContainer)
        
        // Position X
        let positionXContainer = createPropertyRow(label: "Position X:", control: {
            let xField = NSTextField()
            xField.doubleValue = Double(joint.position.x)
            xField.target = self
            xField.action = #selector(jointPositionChanged(_:))
            xField.tag = 0
            return xField
        }())
        propertiesStackView.addArrangedSubview(positionXContainer)
        
        // Position Y
        let positionYContainer = createPropertyRow(label: "Position Y:", control: {
            let yField = NSTextField()
            yField.doubleValue = Double(joint.position.y)
            yField.target = self
            yField.action = #selector(jointPositionChanged(_:))
            yField.tag = 1
            return yField
        }())
        propertiesStackView.addArrangedSubview(positionYContainer)
        
        // Fixed checkbox
        let fixedContainer = createPropertyRow(label: "Fixed:", control: {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(jointFixedChanged(_:)))
            checkbox.state = joint.isFixed ? .on : .off
            return checkbox
        }())
        propertiesStackView.addArrangedSubview(fixedContainer)
        
        // Angle constraints
        if joint.hasAngleConstraints {
            let minAngleContainer = createPropertyRow(label: "Min Angle:", control: {
                let slider = NSSlider()
                slider.minValue = -180
                slider.maxValue = 180
                slider.doubleValue = Double(radiansToDegrees(joint.minAngle))
                slider.target = self
                slider.action = #selector(jointMinAngleChanged(_:))
                return slider
            }())
            propertiesStackView.addArrangedSubview(minAngleContainer)
            
            let maxAngleContainer = createPropertyRow(label: "Max Angle:", control: {
                let slider = NSSlider()
                slider.minValue = -180
                slider.maxValue = 180
                slider.doubleValue = Double(radiansToDegrees(joint.maxAngle))
                slider.target = self
                slider.action = #selector(jointMaxAngleChanged(_:))
                return slider
            }())
            propertiesStackView.addArrangedSubview(maxAngleContainer)
        }
    }
    
    private func setupBoneProperties(_ bone: Bone) {
        let titleLabel = NSTextField(labelWithString: "Bone Properties")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        propertiesStackView.addArrangedSubview(titleLabel)
        
        // Name
        let nameContainer = createPropertyRow(label: "Name:", control: {
            let textField = NSTextField()
            textField.stringValue = bone.name
            textField.target = self
            textField.action = #selector(boneNameChanged(_:))
            return textField
        }())
        propertiesStackView.addArrangedSubview(nameContainer)
        
        // Thickness
        let thicknessContainer = createPropertyRow(label: "Thickness:", control: {
            let slider = NSSlider()
            slider.minValue = 1
            slider.maxValue = 20
            slider.doubleValue = Double(bone.thickness)
            slider.target = self
            slider.action = #selector(boneThicknessChanged(_:))
            return slider
        }())
        propertiesStackView.addArrangedSubview(thicknessContainer)
        
        // Color
        let colorContainer = createPropertyRow(label: "Color:", control: {
            let colorWell = NSColorWell()
            colorWell.color = bone.color
            colorWell.target = self
            colorWell.action = #selector(boneColorChanged(_:))
            return colorWell
        }())
        propertiesStackView.addArrangedSubview(colorContainer)
        
        // Pixel Art
        let pixelArtContainer = createPropertyRow(label: "Pixel Art:", control: {
            let button = NSButton(title: bone.pixelArt != nil ? "Edit" : "Create", target: self, action: #selector(editPixelArt(_:)))
            return button
        }())
        propertiesStackView.addArrangedSubview(pixelArtContainer)
    }
    
    private func setupSkeletonProperties() {
        let titleLabel = NSTextField(labelWithString: "Skeleton Properties")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        propertiesStackView.addArrangedSubview(titleLabel)
        
        let nameContainer = createPropertyRow(label: "Name:", control: {
            let textField = NSTextField()
            textField.stringValue = skeleton.name
            textField.target = self
            textField.action = #selector(skeletonNameChanged(_:))
            return textField
        }())
        propertiesStackView.addArrangedSubview(nameContainer)
        
        let statsLabel = NSTextField(labelWithString: "Joints: \(skeleton.joints.count), Bones: \(skeleton.bones.count)")
        propertiesStackView.addArrangedSubview(statsLabel)
    }
    
    private func createPropertyRow(label: String, control: NSView) -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 8
        container.alignment = .centerY
        container.distribution = .fill
        
        let labelView = NSTextField(labelWithString: label)
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        labelView.setContentCompressionResistancePriority(.required, for: .horizontal)
        labelView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // Ensure the control has a minimum width to display content properly
        if let textField = control as? NSTextField {
            textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        }
        
        container.addArrangedSubview(labelView)
        container.addArrangedSubview(control)
        
        return container
    }
    
    // MARK: - Property Actions
    
    @objc private func jointNameChanged(_ sender: NSTextField) {
        selectedJoint?.name = sender.stringValue
        isModified = true
    }
    
    @objc private func jointPositionChanged(_ sender: NSTextField) {
        guard let joint = selectedJoint else { return }
        
        if sender.tag == 0 { // x
            joint.position.x = Float(sender.doubleValue)
        } else { // y
            joint.position.y = Float(sender.doubleValue)
        }
        
        skeletalEditorView.needsDisplay = true
        isModified = true
    }
    
    @objc private func jointFixedChanged(_ sender: NSButton) {
        selectedJoint?.isFixed = sender.state == .on
        skeletalEditorView.needsDisplay = true
        isModified = true
    }
    
    @objc private func jointMinAngleChanged(_ sender: NSSlider) {
        selectedJoint?.minAngle = degreesToRadians(Float(sender.doubleValue))
        isModified = true
    }
    
    @objc private func jointMaxAngleChanged(_ sender: NSSlider) {
        selectedJoint?.maxAngle = degreesToRadians(Float(sender.doubleValue))
        isModified = true
    }
    
    @objc private func boneNameChanged(_ sender: NSTextField) {
        selectedBone?.name = sender.stringValue
        isModified = true
    }
    
    @objc private func boneThicknessChanged(_ sender: NSSlider) {
        selectedBone?.thickness = Float(sender.doubleValue)
        skeletalEditorView.needsDisplay = true
        isModified = true
    }
    
    @objc private func boneColorChanged(_ sender: NSColorWell) {
        selectedBone?.color = sender.color
        skeletalEditorView.needsDisplay = true
        isModified = true
    }
    
    @objc private func editPixelArt(_ sender: NSButton) {
        guard let bone = selectedBone else { return }
        
        let pixelArtEditor = PixelArtEditorWindow(bone: bone)
        pixelArtEditor.delegate = skeletalEditorView
        pixelArtEditor.showWindow(nil)
    }
    
    @objc private func skeletonNameChanged(_ sender: NSTextField) {
        skeleton.name = sender.stringValue
        documentName = sender.stringValue
        updateTabTitle()
        isModified = true
    }
    
    // MARK: - Import/Export
    
    private func exportSkeletonToJSON(url: URL) {
        do {
            let skeletonData = SkeletonData(from: skeleton)
            let jsonData = try JSONEncoder().encode(skeletonData)
            try jsonData.write(to: url)
            
            let alert = NSAlert()
            alert.messageText = "Skeleton Exported"
            alert.informativeText = "The skeleton has been successfully exported to \(url.lastPathComponent)"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Failed to export skeleton: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    
    private func importSkeletonFromJSON(url: URL) {
        do {
            let jsonData = try Data(contentsOf: url)
            let skeletonData = try JSONDecoder().decode(SkeletonData.self, from: jsonData)
            
            // Create new skeleton from imported data
            let newSkeleton = Skeleton(name: skeletonData.name)
            
            // Import joints
            var jointMap: [String: Joint] = [:]
            for jointData in skeletonData.joints {
                let joint = Joint(name: jointData.name, position: simd_float2(jointData.position.x, jointData.position.y))
                joint.rotation = jointData.rotation
                joint.isFixed = jointData.isFixed
                joint.minAngle = jointData.minAngle
                joint.maxAngle = jointData.maxAngle
                joint.hasAngleConstraints = jointData.hasAngleConstraints
                newSkeleton.addJoint(joint)
                jointMap[jointData.id] = joint
            }
            
            // Import bones
            for boneData in skeletonData.bones {
                guard let startJoint = jointMap[boneData.startJointId],
                      let endJoint = jointMap[boneData.endJointId] else { continue }
                
                let originalLength = boneData.originalLength ?? {
                    let diff = endJoint.position - startJoint.position
                    return simd_length(diff)
                }()
                let bone = Bone(name: boneData.name, start: startJoint, end: endJoint, originalLength: originalLength)
                bone.thickness = boneData.thickness
                bone.color = NSColor(red: CGFloat(boneData.color.r), 
                                   green: CGFloat(boneData.color.g), 
                                   blue: CGFloat(boneData.color.b), 
                                   alpha: CGFloat(boneData.color.a))
                newSkeleton.addBone(bone)
            }
            
            // Set root joint
            if let rootId = skeletonData.rootJointId {
                newSkeleton.rootJoint = jointMap[rootId]
            }
            
            // Replace current skeleton
            skeleton = newSkeleton
            skeletalEditorView.skeleton = skeleton
            updatePropertiesPanel()
            skeletalEditorView.needsDisplay = true
            
            let alert = NSAlert()
            alert.messageText = "Skeleton Imported"
            alert.informativeText = "The skeleton has been successfully imported from \(url.lastPathComponent)"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = "Failed to import skeleton: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
}

// MARK: - SkeletalEditorDelegate

extension SkeletalDocumentViewController: SkeletalEditorDelegate {
    func skeletalEditor(_ editor: SkeletalEditorView, didSelectBone bone: Bone?) {
        selectedBone = bone
        selectedJoint = nil
        updatePropertiesPanel()
    }
    
    func skeletalEditor(_ editor: SkeletalEditorView, didSelectJoint joint: Joint?) {
        selectedJoint = joint
        selectedBone = nil
        updatePropertiesPanel()
    }
    
    func skeletalEditor(_ editor: SkeletalEditorView, didModifySkeleton skeleton: Skeleton) {
        isModified = true
        updatePropertiesPanel()
    }
}



// MARK: - Extensions

extension NSRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}