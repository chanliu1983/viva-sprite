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
    private var toolButtons: [NSButton] = []
    private var modeButtons: [NSButton] = []
  private var propertiesStackView: NSStackView!
    
    // MARK: - Properties
    
    var skeleton: Skeleton!
    var documentName: String = "Untitled Skeleton"
    var isModified: Bool = false {
        didSet {
            updateTabTitle()
        }
    }
    
    // Canvas size properties for early initialization
    private var pendingCanvasWidth: Int?
    private var pendingCanvasHeight: Int?
    
    weak var tabViewController: TabViewController?
    
    private var selectedJoint: Joint?
    private var selectedBone: Bone?
    
    private var pixelArtEditorWindow: PixelArtEditorWindow?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSkeleton()
        setupProperties()
        
        // Configure skeletal editor after UI is set up
        skeletalEditorView.skeleton = skeleton
        skeletalEditorView.delegate = self
        
        // Set initial tool to Move mode
        skeletalEditorView.currentTool = .move
        
        configureInitialSettings()
    }
    
    func setCanvasSize(width: Int, height: Int) {
        if skeleton != nil {
            skeleton.canvasWidth = width
            skeleton.canvasHeight = height
            skeletalEditorView?.needsDisplay = true
        } else {
            // Store for later application when skeleton is initialized
            pendingCanvasWidth = width
            pendingCanvasHeight = height
        }
    }
    
    private func configureInitialSettings() {
        updateToolSelection(for: .move)
        
        // Set initial mode to Direct
        skeletalEditorView.currentMode = .direct
        updateModeSelection(for: .direct)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Make the skeletal editor view the first responder to receive keyboard events
        view.window?.makeFirstResponder(skeletalEditorView)
    }
    
    // MARK: - Setup
    
    private func setupSkeleton() {
        skeleton = Skeleton(name: documentName)
        
        // Apply pending canvas size if it was set before skeleton initialization
        if let width = pendingCanvasWidth, let height = pendingCanvasHeight {
            skeleton.canvasWidth = width
            skeleton.canvasHeight = height
            pendingCanvasWidth = nil
            pendingCanvasHeight = nil
        }
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
        let toolButtonContainer = NSStackView()
        toolButtonContainer.orientation = .horizontal
        toolButtonContainer.spacing = 0
        toolButtonContainer.distribution = .fillEqually

        let toolInfo: [(String, String, SkeletalEditorView.SkeletalTool, String)] = [
            ("Move", "move.3d", .move, "m"),
            ("Select", "hand.tap", .select, "s"),
            ("Add", "plus.circle", .addJointBone, "a"),
            ("Delete", "trash", .delete, "d")
        ]

        for (title, iconName, tool, key) in toolInfo {
            let button = NSButton()
            button.setButtonType(.toggle)
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
            button.toolTip = title
            button.target = self
            button.action = #selector(toolChanged(_:))
            button.tag = tool.rawValue
            button.keyEquivalent = key
            toolButtonContainer.addArrangedSubview(button)
            toolButtons.append(button)
        }

        leftStackView.addArrangedSubview(toolButtonContainer)
        
        // Create mode section
        let modeLabel = NSTextField(labelWithString: "Mode")
        modeLabel.font = NSFont.boldSystemFont(ofSize: 14)
        leftStackView.addArrangedSubview(modeLabel)
        
        // Setup mode control
        let modeButtonContainer = NSStackView()
        modeButtonContainer.orientation = .horizontal
        modeButtonContainer.spacing = 0
        modeButtonContainer.distribution = .fillEqually

        let modeInfo: [(String, String, SkeletalEditorView.SkeletalMode, String)] = [
            ("Direct", "arrow.up.and.down.and.arrow.left.and.right", .direct, "q"),
            ("IK", "move.3d", .ik, "w")
        ]

        for (title, iconName, mode, key) in modeInfo {
            let button = NSButton()
            button.setButtonType(.toggle)
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
            button.toolTip = title
            button.target = self
            button.action = #selector(modeChanged(_:))
            button.tag = mode.rawValue
            button.keyEquivalent = key
            modeButtonContainer.addArrangedSubview(button)
            modeButtons.append(button)
        }

        leftStackView.addArrangedSubview(modeButtonContainer)
        

        
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

            // Tool button constraints
            toolButtonContainer.heightAnchor.constraint(equalToConstant: 60),
            toolButtonContainer.widthAnchor.constraint(equalToConstant: 334),
            

            modeButtonContainer.heightAnchor.constraint(equalToConstant: 60),
            modeButtonContainer.widthAnchor.constraint(equalToConstant: 334),
            
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
    
    @objc func toolChanged(_ sender: NSButton) {
        guard let tool = SkeletalEditorView.SkeletalTool(rawValue: sender.tag) else { return }
        skeletalEditorView.currentTool = tool
        updateToolSelection(for: tool)
    }
    
    @objc func modeChanged(_ sender: NSButton) {
        guard let mode = SkeletalEditorView.SkeletalMode(rawValue: sender.tag) else { return }
        skeletalEditorView.setMode(mode)
        updateModeSelection(for: mode)
    }

    func updateModeSelection(for mode: SkeletalEditorView.SkeletalMode) {
        for button in modeButtons {
            if button.tag == mode.rawValue {
                button.state = .on
            } else {
                button.state = .off
            }
        }
    }
    
    func updateToolSelection(for tool: SkeletalEditorView.SkeletalTool) {
        for button in toolButtons {
            if button.tag == tool.rawValue {
                button.state = .on
            } else {
                button.state = .off
            }
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
            
            do {
                let data = try JSONEncoder().encode(skeleton.data)
                try data.write(to: url)
                isModified = false
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Exporting Skeleton"
                alert.informativeText = "Could not save the skeleton to the specified file.\n\n\(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
    
    @objc func importSkeleton(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            guard let url = openPanel.urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let skeletonData = try JSONDecoder().decode(SkeletonData.self, from: data)
                
                if let newSkeleton = Skeleton(from: skeletonData) {
                    // Preserve current canvas size when importing
                    let currentCanvasWidth = self.skeleton?.canvasWidth ?? 1024
                    let currentCanvasHeight = self.skeleton?.canvasHeight ?? 1024
                    newSkeleton.canvasWidth = currentCanvasWidth
                    newSkeleton.canvasHeight = currentCanvasHeight
                    
                    self.skeleton = newSkeleton
                    self.skeletalEditorView.skeleton = newSkeleton
                    self.documentName = newSkeleton.name
                    self.isModified = false
                    updatePropertiesPanel()
                    skeletalEditorView.needsDisplay = true
                } else {
                    throw NSError(domain: "VivaSpriteError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to reconstruct skeleton from data."])
                }
                
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Importing Skeleton"
                alert.informativeText = "Could not load the skeleton from the specified file.\n\n\(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }
    
    @objc func exportAsImage(_ sender: Any) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "\(documentName).png"
        
        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            
            // Create an offscreen view with the same content as the skeletal editor
            let offscreenView = SkeletalEditorView(frame: skeletalEditorView.bounds)
            offscreenView.skeleton = self.skeleton
            offscreenView.canvasOffset = self.skeletalEditorView.canvasOffset
            
            // Generate the image from the offscreen view
            guard let image = offscreenView.exportAsImage() else {
                let alert = NSAlert()
                alert.messageText = "Error Exporting Image"
                alert.informativeText = "Could not generate the image."
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
            
            // Convert to PNG data
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                let alert = NSAlert()
                alert.messageText = "Error Exporting Image"
                alert.informativeText = "Could not generate the PNG data for the image."
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
            
            // Save the PNG data to the selected URL
            do {
                try pngData.write(to: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "Error Saving Image"
                alert.informativeText = "Failed to save the image to the selected location.\n\n\(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.runModal()
            }
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
    
    @objc func bonePixelArtScaleChanged(_ sender: NSSlider) {
        guard let bone = selectedBone else { return }
        bone.pixelArtScale = sender.floatValue
        skeletalEditorView.needsDisplay = true
        isModified = true
    }

    @objc func bonePixelArtRotationChanged(_ sender: NSSlider) {
        guard let bone = selectedBone else { return }
        bone.pixelArtRotation = degreesToRadians(sender.floatValue)
        skeletalEditorView.needsDisplay = true
        isModified = true
    }
    
    @objc func bonePixelArtOrderChanged(_ sender: NSSlider) {
        guard let bone = selectedBone else { return }
        bone.pixelArtOrder = sender.integerValue
        skeletalEditorView.needsDisplay = true
        isModified = true
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

        // Pixel Art Scale
        let scaleContainer = createPropertyRow(label: "Pixel Art Scale:", control: {
            let slider = NSSlider()
            slider.minValue = 0.1
            slider.maxValue = 10.0
            slider.floatValue = bone.pixelArtScale
            slider.target = self
            slider.action = #selector(bonePixelArtScaleChanged(_:))
            return slider
        }())
        propertiesStackView.addArrangedSubview(scaleContainer)

        // Pixel Art Rotation
        let rotationContainer = createPropertyRow(label: "Pixel Art Rotation:", control: {
            let slider = NSSlider()
            slider.minValue = -180
            slider.maxValue = 180
            slider.floatValue = radiansToDegrees(bone.pixelArtRotation)
            slider.target = self
            slider.action = #selector(bonePixelArtRotationChanged(_:))
            return slider
        }())
        propertiesStackView.addArrangedSubview(rotationContainer)
        
        // Pixel Art Order
        let orderContainer = createPropertyRow(label: "Pixel Art Order:", control: {
            let slider = NSSlider()
            slider.minValue = -10
            slider.maxValue = 10
            slider.integerValue = bone.pixelArtOrder
            slider.target = self
            slider.action = #selector(bonePixelArtOrderChanged(_:))
            return slider
        }())
        propertiesStackView.addArrangedSubview(orderContainer)
        
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
        self.pixelArtEditorWindow = pixelArtEditor // Retain reference
        
        // Present as sheet to maintain proper window hierarchy and event routing
        if let parentWindow = self.view.window {
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
    
    @objc private func skeletonNameChanged(_ sender: NSTextField) {
        skeleton.name = sender.stringValue
        documentName = sender.stringValue
        updateTabTitle()
        isModified = true
    }
    
    // MARK: - Import/Export
    

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