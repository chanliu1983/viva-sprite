//
//  SkeletalSystem.swift
//  VivaSprite
//
//  Skeletal Animation System with IK Resolution
//

import Cocoa
import simd

// MARK: - Core Data Structures

/// Represents a joint in the skeletal system
class Joint {
    let id: UUID
    var name: String
    var position: simd_float2
    var rotation: Float = 0.0
    var isFixed: Bool = false
    
    weak var parent: Joint?
    var children: [Joint] = []
    
    // IK constraints
    var minAngle: Float = -Float.pi
    var maxAngle: Float = Float.pi
    var hasAngleConstraints: Bool = false
    
    init(name: String, position: simd_float2) {
        self.id = UUID()
        self.name = name
        self.position = position
    }
    
    func addChild(_ child: Joint) {
        child.parent = self
        children.append(child)
    }
    
    func removeChild(_ child: Joint) {
        child.parent = nil
        children.removeAll { $0.id == child.id }
    }
    
    /// Get world position considering parent transformations
    func worldPosition() -> simd_float2 {
        guard let parent = parent else { return position }
        let parentWorld = parent.worldPosition()
        let rotatedPos = rotateVector(position, by: parent.rotation)
        return parentWorld + rotatedPos
    }
    
    /// Get world rotation considering parent rotations
    func worldRotation() -> Float {
        guard let parent = parent else { return rotation }
        return parent.worldRotation() + rotation
    }
}

/// Represents a bone connecting two joints
class Bone {
    let id: UUID
    var name: String
    let startJoint: Joint
    let endJoint: Joint
    var pixelArt: PixelArtData?
    var thickness: Float = 10.0
    var color: NSColor = .brown
    
    init(name: String, start: Joint, end: Joint) {
        self.id = UUID()
        self.name = name
        self.startJoint = start
        self.endJoint = end
    }
    
    var length: Float {
        let diff = endJoint.position - startJoint.position
        return simd_length(diff)
    }
    
    var angle: Float {
        let diff = endJoint.position - startJoint.position
        return atan2(diff.y, diff.x)
    }
}

/// Pixel art data that can be bound to bones
struct PixelArtData {
    let id: UUID
    var name: String
    var pixels: [[NSColor?]]
    var width: Int
    var height: Int
    var anchorPoint: simd_float2 // Relative anchor point (0-1)
    
    init(name: String, width: Int, height: Int) {
        self.id = UUID()
        self.name = name
        self.width = width
        self.height = height
        self.pixels = Array(repeating: Array(repeating: nil, count: width), count: height)
        self.anchorPoint = simd_float2(0.5, 0.5) // Center by default
    }
}

/// Complete skeletal structure
class Skeleton {
    let id: UUID
    var name: String
    var rootJoint: Joint?
    var joints: [Joint] = []
    var bones: [Bone] = []
    var pixelArts: [PixelArtData] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
    
    func addJoint(_ joint: Joint) {
        joints.append(joint)
        if rootJoint == nil {
            rootJoint = joint
        }
    }
    
    func removeJoint(_ joint: Joint) {
        // Remove associated bones
        bones.removeAll { $0.startJoint.id == joint.id || $0.endJoint.id == joint.id }
        
        // Remove from parent
        joint.parent?.removeChild(joint)
        
        // Remove from joints array
        joints.removeAll { $0.id == joint.id }
        
        // Update root if necessary
        if rootJoint?.id == joint.id {
            rootJoint = joints.first
        }
    }
    
    func addBone(_ bone: Bone) {
        bones.append(bone)
    }
    
    func removeBone(_ bone: Bone) {
        bones.removeAll { $0.id == bone.id }
    }
    
    func addPixelArt(_ pixelArt: PixelArtData) {
        pixelArts.append(pixelArt)
    }
    
    func removePixelArt(_ pixelArt: PixelArtData) {
        pixelArts.removeAll { $0.id == pixelArt.id }
        
        // Remove from bones
        for bone in bones {
            if bone.pixelArt?.id == pixelArt.id {
                bone.pixelArt = nil
            }
        }
    }
}

// MARK: - IK Solver

class IKSolver {
    
    /// Solve IK using FABRIK (Forward And Backward Reaching Inverse Kinematics)
    static func solveIK(chain: [Joint], target: simd_float2, iterations: Int = 10, tolerance: Float = 0.01) {
        guard chain.count >= 2 else { return }
        
        // Store original positions
        let originalPositions = chain.map { $0.position }
        
        // Calculate bone lengths
        var boneLengths: [Float] = []
        for i in 0..<chain.count - 1 {
            let length = simd_distance(chain[i].position, chain[i + 1].position)
            boneLengths.append(length)
        }
        
        let totalLength = boneLengths.reduce(0, +)
        let distanceToTarget = simd_distance(chain[0].position, target)
        
        // Check if target is reachable
        if distanceToTarget > totalLength {
            // Target is too far, stretch towards it
            let direction = simd_normalize(target - chain[0].position)
            var currentPos = chain[0].position
            
            for i in 1..<chain.count {
                currentPos += direction * boneLengths[i - 1]
                chain[i].position = currentPos
            }
            return
        }
        
        // FABRIK algorithm
        for _ in 0..<iterations {
            // Forward reaching
            chain[chain.count - 1].position = target
            
            for i in stride(from: chain.count - 2, through: 0, by: -1) {
                let direction = simd_normalize(chain[i].position - chain[i + 1].position)
                chain[i].position = chain[i + 1].position + direction * boneLengths[i]
            }
            
            // Backward reaching
            chain[0].position = originalPositions[0] // Keep root fixed
            
            for i in 1..<chain.count {
                let direction = simd_normalize(chain[i].position - chain[i - 1].position)
                chain[i].position = chain[i - 1].position + direction * boneLengths[i - 1]
            }
            
            // Check convergence
            if simd_distance(chain[chain.count - 1].position, target) < tolerance {
                break
            }
        }
        
        // Apply angle constraints
        applyAngleConstraints(chain: chain)
    }
    
    private static func applyAngleConstraints(chain: [Joint]) {
        for i in 1..<chain.count {
            let joint = chain[i]
            guard joint.hasAngleConstraints else { continue }
            
            let parent = chain[i - 1]
            let direction = joint.position - parent.position
            let currentAngle = atan2(direction.y, direction.x)
            
            let clampedAngle = max(joint.minAngle, min(joint.maxAngle, currentAngle))
            
            if abs(currentAngle - clampedAngle) > 0.001 {
                let length = simd_length(direction)
                joint.position = parent.position + simd_float2(cos(clampedAngle), sin(clampedAngle)) * length
            }
        }
    }
}

// MARK: - Utility Functions

func rotateVector(_ vector: simd_float2, by angle: Float) -> simd_float2 {
    let cos_a = cos(angle)
    let sin_a = sin(angle)
    return simd_float2(
        vector.x * cos_a - vector.y * sin_a,
        vector.x * sin_a + vector.y * cos_a
    )
}

func degreesToRadians(_ degrees: Float) -> Float {
    return degrees * Float.pi / 180.0
}

func radiansToDegrees(_ radians: Float) -> Float {
    return radians * 180.0 / Float.pi
}

// MARK: - Extensions

extension simd_float2 {
    var cgPoint: CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    init(_ point: CGPoint) {
        self.init(Float(point.x), Float(point.y))
    }
}

extension CGPoint {
    var simdFloat2: simd_float2 {
        return simd_float2(Float(x), Float(y))
    }
}