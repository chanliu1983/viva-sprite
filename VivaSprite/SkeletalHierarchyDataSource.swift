//
//  SkeletalHierarchyDataSource.swift
//  VivaSprite
//
//  Data source for the skeletal hierarchy outline view
//

import Cocoa

class SkeletalHierarchyDataSource: NSObject, NSOutlineViewDataSource {
    
    private var skeleton: Skeleton
    
    init(skeleton: Skeleton) {
        self.skeleton = skeleton
        super.init()
    }
    
    func updateSkeleton(_ newSkeleton: Skeleton) {
        self.skeleton = newSkeleton
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            // Root level - show all joints and bones in flat structure
            return skeleton.joints.count + skeleton.bones.count
        }
        
        // No hierarchy - all items are at root level
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            // Root level - return joints first, then bones
            if index < skeleton.joints.count {
                return skeleton.joints[index]
            } else {
                let boneIndex = index - skeleton.joints.count
                return skeleton.bones[boneIndex]
            }
        }
        
        // No hierarchy - shouldn't reach here
        return NSNull()
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        // No hierarchy - nothing is expandable
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