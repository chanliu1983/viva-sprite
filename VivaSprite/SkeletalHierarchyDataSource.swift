//
//  SkeletalHierarchyDataSource.swift
//  VivaSprite
//
//  Data source for the skeletal hierarchy outline view
//

import Cocoa

class SkeletalHierarchyDataSource: NSObject, NSOutlineViewDataSource {
    
    private let skeleton: Skeleton
    
    init(skeleton: Skeleton) {
        self.skeleton = skeleton
        super.init()
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            // Root level - show root joints
            return skeleton.joints.filter { $0.parent == nil }.count
        }
        
        if let joint = item as? Joint {
            // Show child joints and bones connected to this joint
            let childJoints = joint.children.count
            let connectedBones = skeleton.bones.filter { $0.startJoint.id == joint.id || $0.endJoint.id == joint.id }.count
            return childJoints + connectedBones
        }
        
        if let bone = item as? Bone {
            // Bones don't have children in this hierarchy
            return 0
        }
        
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            // Root level - return root joints
            let rootJoints = skeleton.joints.filter { $0.parent == nil }
            return rootJoints[index]
        }
        
        if let joint = item as? Joint {
            // Return child joints first, then connected bones
            let childJoints = joint.children
            let connectedBones = skeleton.bones.filter { $0.startJoint.id == joint.id || $0.endJoint.id == joint.id }
            
            if index < childJoints.count {
                return childJoints[index]
            } else {
                let boneIndex = index - childJoints.count
                return connectedBones[boneIndex]
            }
        }
        
        // This shouldn't happen for bones since they don't have children
        return NSNull()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let joint = item as? Joint {
            let childJoints = joint.children.count
            let connectedBones = skeleton.bones.filter { $0.startJoint.id == joint.id || $0.endJoint.id == joint.id }.count
            return (childJoints + connectedBones) > 0
        }
        
        // Bones are not expandable
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        if let joint = item as? Joint {
            switch identifier {
            case "name":
                return joint.name + (joint.isFixed ? " (Fixed)" : "")
            case "type":
                return "Joint"
            default:
                return joint.name
            }
        }
        
        if let bone = item as? Bone {
            switch identifier {
            case "name":
                return bone.name + (bone.pixelArt != nil ? " 🎨" : "")
            case "type":
                return "Bone"
            default:
                return bone.name
            }
        }
        
        return nil
    }
    
    // MARK: - Drag and Drop Support (Optional)
    
    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        // Enable drag and drop for reordering
        let itemIDs = items.compactMap { item -> String? in
            if let joint = item as? Joint {
                return "joint_\(joint.id)"
            } else if let bone = item as? Bone {
                return "bone_\(bone.id)"
            }
            return nil
        }
        
        pasteboard.declareTypes([.string], owner: self)
        pasteboard.setString(itemIDs.joined(separator: ","), forType: .string)
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        // Only allow dropping on joints (to change parent-child relationships)
        if item is Joint || item == nil {
            return .move
        }
        return []
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let pasteboard = info.draggingPasteboard.string(forType: .string) else {
            return false
        }
        
        let _ = pasteboard.components(separatedBy: ",")
        
        // Handle the drop logic here
        // This would involve updating the parent-child relationships in the skeleton
        // For now, we'll just return true to indicate the drop was accepted
        
        return true
    }
}

// MARK: - Helper Extensions

extension SkeletalHierarchyDataSource {
    
    func refreshData() {
        // This method can be called when the skeleton structure changes
        // to notify any listening outline views to reload their data
    }
    
    func findItem(withID id: UUID, type: ItemType) -> Any? {
        switch type {
        case .joint:
            return skeleton.joints.first { $0.id == id }
        case .bone:
            return skeleton.bones.first { $0.id == id }
        }
    }
    
    enum ItemType {
        case joint
        case bone
    }
}