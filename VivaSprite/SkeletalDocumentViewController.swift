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
    var toolSegmentedControl: NSSegmentedControl!
    var modeSegmentedControl: NSSegmentedControl!
    var hierarchyOutlineView: NSOutlineView!
    var propertiesStackView: NSStackView!
    
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
    private var hierarchyDataSource: SkeletalHierarchyDataSource!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSkeleton()
        setupUI()
        setupHierarchy()
        setupProperties()
        
        // Configure skeletal editor after UI is set up
        skeletalEditorView.skeleton = skeleton
        skeletalEditorView.delegate = self
    }
    
    // MARK: - Setup
    
    private func setupSkeleton() {
        skeleton = Skeleton(name: documentName)
        
        // Create a simple default skeleton
        createDefaultSkeleton()
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
        root.addChild(torso)
        
        // Create head
        let head = Joint(name: "Head", position: simd_float2(400, 400))
        skeleton.addJoint(head)
        
        let neck = Bone(name: "Neck", start: torso, end: head)
        skeleton.addBone(neck)
        torso.addChild(head)
        
        // Create left arm
        let leftShoulder = Joint(name: "Left Shoulder", position: simd_float2(370, 340))
        skeleton.addJoint(leftShoulder)
        
        let leftUpperArm = Bone(name: "Left Upper Arm", start: torso, end: leftShoulder)
        skeleton.addBone(leftUpperArm)
        torso.addChild(leftShoulder)
        
        let leftElbow = Joint(name: "Left Elbow", position: simd_float2(340, 320))
        skeleton.addJoint(leftElbow)
        
        let leftForearm = Bone(name: "Left Forearm", start: leftShoulder, end: leftElbow)
        skeleton.addBone(leftForearm)
        leftShoulder.addChild(leftElbow)
        
        let leftHand = Joint(name: "Left Hand", position: simd_float2(310, 300))
        skeleton.addJoint(leftHand)
        
        let leftHand_bone = Bone(name: "Left Hand", start: leftElbow, end: leftHand)
        skeleton.addBone(leftHand_bone)
        leftElbow.addChild(leftHand)
        
        // Create right arm (mirrored)
        let rightShoulder = Joint(name: "Right Shoulder", position: simd_float2(430, 340))
        skeleton.addJoint(rightShoulder)
        
        let rightUpperArm = Bone(name: "Right Upper Arm", start: torso, end: rightShoulder)
        skeleton.addBone(rightUpperArm)
        torso.addChild(rightShoulder)
        
        let rightElbow = Joint(name: "Right Elbow", position: simd_float2(460, 320))
        skeleton.addJoint(rightElbow)
        
        let rightForearm = Bone(name: "Right Forearm", start: rightShoulder, end: rightElbow)
        skeleton.addBone(rightForearm)
        rightShoulder.addChild(rightElbow)
        
        let rightHand = Joint(name: "Right Hand", position: simd_float2(490, 300))
        skeleton.addJoint(rightHand)
        
        let rightHand_bone = Bone(name: "Right Hand", start: rightElbow, end: rightHand)
        skeleton.addBone(rightHand_bone)
        rightElbow.addChild(rightHand)
        
        // Create legs
        let leftHip = Joint(name: "Left Hip", position: simd_float2(385, 280))
        skeleton.addJoint(leftHip)
        
        let leftThigh = Bone(name: "Left Thigh", start: root, end: leftHip)
        skeleton.addBone(leftThigh)
        root.addChild(leftHip)
        
        let leftKnee = Joint(name: "Left Knee", position: simd_float2(380, 220))
        skeleton.addJoint(leftKnee)
        
        let leftShin = Bone(name: "Left Shin", start: leftHip, end: leftKnee)
        skeleton.addBone(leftShin)
        leftHip.addChild(leftKnee)
        
        let leftFoot = Joint(name: "Left Foot", position: simd_float2(375, 160))
        skeleton.addJoint(leftFoot)
        
        let leftFoot_bone = Bone(name: "Left Foot", start: leftKnee, end: leftFoot)
        skeleton.addBone(leftFoot_bone)
        leftKnee.addChild(leftFoot)
        
        // Right leg (mirrored)
        let rightHip = Joint(name: "Right Hip", position: simd_float2(415, 280))
        skeleton.addJoint(rightHip)
        
        let rightThigh = Bone(name: "Right Thigh", start: root, end: rightHip)
        skeleton.addBone(rightThigh)
        root.addChild(rightHip)
        
        let rightKnee = Joint(name: "Right Knee", position: simd_float2(420, 220))
        skeleton.addJoint(rightKnee)
        
        let rightShin = Bone(name: "Right Shin", start: rightHip, end: rightKnee)
        skeleton.addBone(rightShin)
        rightHip.addChild(rightKnee)
        
        let rightFoot = Joint(name: "Right Foot", position: simd_float2(425, 160))
        skeleton.addJoint(rightFoot)
        
        let rightFoot_bone = Bone(name: "Right Foot", start: rightKnee, end: rightFoot)
        skeleton.addBone(rightFoot_bone)
        rightKnee.addChild(rightFoot)
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
        toolSegmentedControl = NSSegmentedControl()
        toolSegmentedControl.segmentCount = 4
        toolSegmentedControl.setLabel("Select", forSegment: 0)
        toolSegmentedControl.setLabel("Add Joint", forSegment: 1)
        toolSegmentedControl.setLabel("Add Bone", forSegment: 2)
        toolSegmentedControl.setLabel("Delete", forSegment: 3)
        toolSegmentedControl.selectedSegment = 0
        toolSegmentedControl.target = self
        toolSegmentedControl.action = #selector(toolChanged(_:))
        leftStackView.addArrangedSubview(toolSegmentedControl)
        
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
        
        // Create hierarchy section
        let hierarchyLabel = NSTextField(labelWithString: "Hierarchy")
        hierarchyLabel.font = NSFont.boldSystemFont(ofSize: 14)
        leftStackView.addArrangedSubview(hierarchyLabel)
        
        // Create hierarchy outline view in scroll view
        let hierarchyScrollView = NSScrollView()
        hierarchyScrollView.borderType = .bezelBorder
        hierarchyScrollView.hasVerticalScroller = true
        hierarchyScrollView.hasHorizontalScroller = true
        hierarchyScrollView.autohidesScrollers = true
        
        hierarchyOutlineView = NSOutlineView()
        hierarchyOutlineView.headerView = nil
        hierarchyOutlineView.allowsMultipleSelection = false
        
        hierarchyScrollView.documentView = hierarchyOutlineView
        leftStackView.addArrangedSubview(hierarchyScrollView)
        
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
        propertiesStackView.spacing = 8
        
        propertiesScrollView.documentView = propertiesStackView
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
            leftPanel.widthAnchor.constraint(equalToConstant: 250),
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
            toolSegmentedControl.widthAnchor.constraint(equalToConstant: 234),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 234),
            
            // Scroll view heights
            hierarchyScrollView.heightAnchor.constraint(equalToConstant: 200),
            propertiesScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        
        // Set split view position
        splitView.setPosition(250, ofDividerAt: 0)
    }
    
    private func setupHierarchy() {
        hierarchyDataSource = SkeletalHierarchyDataSource(skeleton: skeleton)
        hierarchyOutlineView.dataSource = hierarchyDataSource
        hierarchyOutlineView.delegate = self
        
        // Setup columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        hierarchyOutlineView.addTableColumn(nameColumn)
        
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.width = 80
        hierarchyOutlineView.addTableColumn(typeColumn)
        
        hierarchyOutlineView.outlineTableColumn = nameColumn
        hierarchyOutlineView.reloadData()
        hierarchyOutlineView.expandItem(nil, expandChildren: true)
    }
    
    private func setupProperties() {
        // Properties panel will be populated based on selection
        updatePropertiesPanel()
    }
    
    // MARK: - Actions
    
    @objc func toolChanged(_ sender: NSSegmentedControl) {
        // Tool handling will be implemented based on selection
    }
    
    @objc func modeChanged(_ sender: NSSegmentedControl) {
        let isIKMode = sender.selectedSegment == 1
        skeletalEditorView.toggleIKMode()
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
        } else {
            setupSkeletonProperties()
        }
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
        
        // Position
        let positionContainer = createPropertyRow(label: "Position:", control: {
            let stackView = NSStackView()
            stackView.orientation = .horizontal
            stackView.spacing = 4
            
            let xField = NSTextField()
            xField.doubleValue = Double(joint.position.x)
            xField.target = self
            xField.action = #selector(jointPositionChanged(_:))
            xField.tag = 0
            
            let yField = NSTextField()
            yField.doubleValue = Double(joint.position.y)
            yField.target = self
            yField.action = #selector(jointPositionChanged(_:))
            yField.tag = 1
            
            stackView.addArrangedSubview(xField)
            stackView.addArrangedSubview(yField)
            return stackView
        }())
        propertiesStackView.addArrangedSubview(positionContainer)
        
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
        
        let labelView = NSTextField(labelWithString: label)
        labelView.setContentHuggingPriority(.required, for: .horizontal)
        labelView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        container.addArrangedSubview(labelView)
        container.addArrangedSubview(control)
        
        return container
    }
    
    // MARK: - Property Actions
    
    @objc private func jointNameChanged(_ sender: NSTextField) {
        selectedJoint?.name = sender.stringValue
        hierarchyOutlineView.reloadData()
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
        hierarchyOutlineView.reloadData()
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
        // Implementation for JSON export
        // This would serialize the skeleton data structure
    }
    
    private func importSkeletonFromJSON(url: URL) {
        // Implementation for JSON import
        // This would deserialize and load skeleton data
    }
}

// MARK: - SkeletalEditorDelegate

extension SkeletalDocumentViewController: SkeletalEditorDelegate {
    func skeletalEditor(_ editor: SkeletalEditorView, didSelectBone bone: Bone?) {
        selectedBone = bone
        selectedJoint = nil
        updatePropertiesPanel()
        
        // Update hierarchy selection
        if let bone = bone {
            let index = skeleton.bones.firstIndex { $0.id == bone.id } ?? -1
            if index >= 0 {
                hierarchyOutlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            }
        }
    }
    
    func skeletalEditor(_ editor: SkeletalEditorView, didSelectJoint joint: Joint?) {
        selectedJoint = joint
        selectedBone = nil
        updatePropertiesPanel()
        
        // Update hierarchy selection
        if let joint = joint {
            let index = skeleton.joints.firstIndex { $0.id == joint.id } ?? -1
            if index >= 0 {
                hierarchyOutlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            }
        }
    }
    
    func skeletalEditor(_ editor: SkeletalEditorView, didModifySkeleton skeleton: Skeleton) {
        isModified = true
        hierarchyOutlineView.reloadData()
    }
}

// MARK: - NSOutlineViewDelegate

extension SkeletalDocumentViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        
        if let joint = item as? Joint {
            if identifier.rawValue == "name" {
                let cellView = NSTableCellView()
                let textField = NSTextField(labelWithString: joint.name)
                cellView.addSubview(textField)
                cellView.textField = textField
                return cellView
            } else if identifier.rawValue == "type" {
                let cellView = NSTableCellView()
                let textField = NSTextField(labelWithString: "Joint")
                cellView.addSubview(textField)
                cellView.textField = textField
                return cellView
            }
        } else if let bone = item as? Bone {
            if identifier.rawValue == "name" {
                let cellView = NSTableCellView()
                let textField = NSTextField(labelWithString: bone.name)
                cellView.addSubview(textField)
                cellView.textField = textField
                return cellView
            } else if identifier.rawValue == "type" {
                let cellView = NSTableCellView()
                let textField = NSTextField(labelWithString: "Bone")
                cellView.addSubview(textField)
                cellView.textField = textField
                return cellView
            }
        }
        
        return nil
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = hierarchyOutlineView.selectedRow
        if selectedRow >= 0 {
            let item = hierarchyOutlineView.item(atRow: selectedRow)
            
            if let joint = item as? Joint {
                selectedJoint = joint
                selectedBone = nil
            } else if let bone = item as? Bone {
                selectedBone = bone
                selectedJoint = nil
            }
            
            updatePropertiesPanel()
        }
    }
}

// MARK: - Extensions

extension NSRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}