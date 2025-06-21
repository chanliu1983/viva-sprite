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
class Joint: Hashable {
    let id: UUID
    var name: String
    var position: simd_float2
    var rotation: Float = 0.0
    var isFixed: Bool = false
    
    // Connected bones for efficient traversal
    var connectedBones: [Bone] = []
    
    // IK constraints
    var minAngle: Float = -Float.pi
    var maxAngle: Float = Float.pi
    var hasAngleConstraints: Bool = false
    
        init(id: UUID = UUID(), name: String, position: simd_float2) {
        self.id = id
        self.name = name
        self.position = position
    }
    
    convenience init?(from data: JointData) {
        guard let id = UUID(uuidString: data.id) else { return nil }
        self.init(id: id, name: data.name, position: simd_float2(x: data.position.x, y: data.position.y))
        self.rotation = data.rotation
        self.isFixed = data.isFixed
        self.minAngle = data.minAngle
        self.maxAngle = data.maxAngle
        self.hasAngleConstraints = data.hasAngleConstraints
    }

    var data: JointData {
        return JointData(from: self)
    }
    
    /// Get world position (simplified - just return local position)
    func worldPosition() -> simd_float2 {
        return position
    }
    
    /// Get world rotation (simplified - just return local rotation)
    func worldRotation() -> Float {
        return rotation
    }
    
    /// Get all joints connected to this joint via bones
    func getConnectedJoints(excluding visited: Set<Joint> = []) -> [Joint] {
        var connectedJoints: [Joint] = []
        
        for bone in connectedBones {
            let otherJoint = (bone.startJoint === self) ? bone.endJoint : bone.startJoint
            if !visited.contains(otherJoint) && !otherJoint.isFixed {
                connectedJoints.append(otherJoint)
            }
        }
        
        return connectedJoints
    }
    
    /// Get all joints connected to this joint via bones (including fixed joints)
    func getAllConnectedJoints(excluding visited: Set<Joint> = []) -> [Joint] {
        var connectedJoints: [Joint] = []
        
        for bone in connectedBones {
            let otherJoint = (bone.startJoint === self) ? bone.endJoint : bone.startJoint
            if !visited.contains(otherJoint) {
                connectedJoints.append(otherJoint)
            }
        }
        
        return connectedJoints
    }
    
    /// Get all bones connected to this joint
    func getConnectedBones() -> [Bone] {
        return connectedBones
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Joint, rhs: Joint) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a bone connecting two joints
class Bone: Hashable {
    let id: UUID
    var name: String
    let startJoint: Joint
    let endJoint: Joint
    var pixelArt: PixelArtData?
    var pixelArtScale: Float = 1.0
    var pixelArtRotation: Float = 0.0 // In radians
    var thickness: Float = 10.0
    var color: NSColor = .brown
    var originalLength: Float // Store the original bone length
    
    init(id: UUID = UUID(), name: String, start: Joint, end: Joint, originalLength: Float) {
        self.id = id
        self.name = name
        self.startJoint = start
        self.endJoint = end
        self.originalLength = originalLength
    }
    
    convenience init(id: UUID = UUID(), name: String, start: Joint, end: Joint) {
        let diff = end.position - start.position
        let length = simd_length(diff)
        self.init(id: id, name: name, start: start, end: end, originalLength: length)
    }

    convenience init?(from data: BoneData, jointMap: [String: Joint], pixelArtMap: [String: PixelArtData]) {
        guard let id = UUID(uuidString: data.id),
              let startJoint = jointMap[data.startJointId],
              let endJoint = jointMap[data.endJointId] else {
            return nil
        }
        let length = data.originalLength ?? simd_distance(startJoint.position, endJoint.position)
        self.init(id: id, name: data.name, start: startJoint, end: endJoint, originalLength: length)
        self.thickness = data.thickness
        self.color = data.color.toNSColor()
        if let pixelArtId = data.pixelArtId {
            guard let pixelArt = pixelArtMap[pixelArtId] else {
                fatalError("Could not find pixel art with ID \(pixelArtId)")
            }
            self.pixelArt = pixelArt
        }
        self.pixelArtScale = data.pixelArtScale ?? 1.0
        self.pixelArtRotation = data.pixelArtRotation ?? 0.0
    }

    var data: BoneData {
        return BoneData(from: self)
    }
    
    var length: Float {
        let diff = endJoint.position - startJoint.position
        return simd_length(diff)
    }
    
    var angle: Float {
        let diff = endJoint.position - startJoint.position
        return atan2(diff.y, diff.x)
    }
    
    func connectedJoint(from joint: Joint) -> Joint? {
        if joint.id == startJoint.id {
            return endJoint
        } else if joint.id == endJoint.id {
            return startJoint
        }
        return nil
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Bone, rhs: Bone) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Pixel art data that can be bound to bones
struct PixelArtData: Identifiable {
    let id: UUID
    var name: String
    var pixels: [[NSColor?]]
    var width: Int
    var height: Int
    var anchorPoint: simd_float2 // Relative anchor point (0-1)
    
    init(id: UUID = UUID(), name: String, width: Int, height: Int) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.pixels = Array(repeating: Array(repeating: nil, count: width), count: height)
        self.anchorPoint = simd_float2(0.5, 0.5) // Center by default
    }

    var codable: PixelArtDataCodable {
        return PixelArtDataCodable(from: self)
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
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    convenience init?(from data: SkeletonData) {
        guard let id = UUID(uuidString: data.id) else { return nil }
        self.init(id: id, name: data.name)

        // Create pixel arts first
        self.pixelArts = data.pixelArts.compactMap { $0.toPixelArtData() }
        let pixelArtMap = Dictionary(uniqueKeysWithValues: self.pixelArts.map { ($0.id.uuidString, $0) })

        // Create joints
        var jointMap: [String: Joint] = [:]
        for jointData in data.joints {
            if let joint = Joint(from: jointData) {
                self.addJoint(joint)
                jointMap[joint.id.uuidString] = joint
            }
        }
        
        // Set root joint
        if let rootJointId = data.rootJointId {
            self.rootJoint = jointMap[rootJointId]
        }

        // Create bones
        for boneData in data.bones {
            if let bone = Bone(from: boneData, jointMap: jointMap, pixelArtMap: pixelArtMap) {
                self.addBone(bone)
            }
        }
    }

    var data: SkeletonData {
        return SkeletonData(from: self)
    }
    
    func addJoint(_ joint: Joint) {
        joints.append(joint)
        if rootJoint == nil {
            rootJoint = joint
        }
    }
    
    func removeJoint(_ joint: Joint) {
        // Remove associated bones and update connections
        let bonesToRemove = bones.filter { $0.startJoint.id == joint.id || $0.endJoint.id == joint.id }
        for bone in bonesToRemove {
            removeBone(bone)
        }
        
        // Clear the joint's connected bones
        joint.connectedBones.removeAll()
        
        // Remove from joints array
        joints.removeAll { $0.id == joint.id }
        
        // Update root if necessary
        if rootJoint?.id == joint.id {
            rootJoint = joints.first
        }
    }
    
    func addBone(_ bone: Bone) {
        bones.append(bone)
        
        // Update joint connections
        if !bone.startJoint.connectedBones.contains(where: { $0.id == bone.id }) {
            bone.startJoint.connectedBones.append(bone)
        }
        if !bone.endJoint.connectedBones.contains(where: { $0.id == bone.id }) {
            bone.endJoint.connectedBones.append(bone)
        }
    }
    
    func removeBone(_ bone: Bone) {
        bones.removeAll { $0.id == bone.id }
        
        // Update joint connections
        bone.startJoint.connectedBones.removeAll { $0.id == bone.id }
        bone.endJoint.connectedBones.removeAll { $0.id == bone.id }
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
    
    /// Generate next available joint name with incremental numbering
    func nextJointName() -> String {
        var counter = 1
        while joints.contains(where: { $0.name == "Joint \(counter)" }) {
            counter += 1
        }
        return "Joint \(counter)"
    }
    
    /// Generate next available bone name with incremental numbering
    func nextBoneName() -> String {
        var counter = 1
        while bones.contains(where: { $0.name == "Bone \(counter)" }) {
            counter += 1
        }
        return "Bone \(counter)"
    }
    
    /// Generate bone name based on joint indices (e.g., "Bone 1-3")
    func boneName(from startJoint: Joint, to endJoint: Joint) -> String {
        let startIndex = getJointIndex(startJoint) ?? 0
        let endIndex = getJointIndex(endJoint) ?? 0
        return "Bone \(startIndex)-\(endIndex)"
    }
    
    /// Get the display index of a joint (1-based)
    private func getJointIndex(_ joint: Joint) -> Int? {
        // Extract number from joint name like "Joint 1", "Joint 2", etc.
        let name = joint.name
        if name.hasPrefix("Joint ") {
            let numberString = String(name.dropFirst(6)) // Remove "Joint "
            return Int(numberString)
        }
        return nil
    }
}

// MARK: - IK Solver

class IKSolver {
    
    /// Find the bone connecting two joints
    private static func findBone(between joint1: Joint, and joint2: Joint, in skeleton: Skeleton) -> Bone? {
        return skeleton.bones.first { bone in
            (bone.startJoint === joint1 && bone.endJoint === joint2) ||
            (bone.startJoint === joint2 && bone.endJoint === joint1)
        }
    }
    
    /// Solve IK using FABRIK (Forward And Backward Reaching Inverse Kinematics)
    static func solveIK(chain: [Joint], target: simd_float2, skeleton: Skeleton, iterations: Int = 20, tolerance: Float = 0.01) {
        guard chain.count >= 2 else { return }
        // Store original positions
        let originalPositions = chain.map { $0.position }
        // Calculate bone lengths using originalLength from Bone objects
        var boneLengths: [Float] = []
        for i in 0..<chain.count - 1 {
            // Find the bone connecting these two joints and use its originalLength
            if let bone = findBone(between: chain[i], and: chain[i + 1], in: skeleton) {
                boneLengths.append(bone.originalLength)
            } else {
                // Fallback to current distance if no bone found (shouldn't happen in normal cases)
                let length = simd_distance(chain[i].position, chain[i + 1].position)
                boneLengths.append(length)
            }
        }
        let totalLength = boneLengths.reduce(0, +)
        let distanceToTarget = simd_distance(chain[0].position, target)
        // If target is unreachable, don't move any joints to maintain bone rigidity
        if distanceToTarget > totalLength {
            // Restore all joints to their original positions to maintain rigid bone lengths
            for i in 0..<chain.count {
                chain[i].position = originalPositions[i]
            }
            return
        }
        // FABRIK iterations
        for _ in 0..<iterations {
            // 1. Forward reaching
            if !chain[chain.count - 1].isFixed {
                chain[chain.count - 1].position = target
            }
            for i in stride(from: chain.count - 2, through: 0, by: -1) {
                if chain[i].isFixed { 
                    // Keep fixed joints at their original positions
                    chain[i].position = originalPositions[i]
                    continue 
                }
                let dir = simd_normalize(chain[i].position - chain[i + 1].position)
                chain[i].position = chain[i + 1].position + dir * boneLengths[i]
            }
            // 2. Backward reaching
            // Only reset root if it's actually fixed, otherwise keep it free
            if chain[0].isFixed {
                chain[0].position = originalPositions[0]
            }

            for i in 1..<chain.count {
                if chain[i].isFixed { continue }
                let dir = simd_normalize(chain[i].position - chain[i - 1].position)
                chain[i].position = chain[i - 1].position + dir * boneLengths[i - 1]
            }
            // Check convergence
            if simd_distance(chain[chain.count - 1].position, target) < tolerance {
                break
            }
        }
        // Final pass: enforce bone lengths while respecting fixed joints
        // Do this in both directions to ensure all bones maintain correct length
        for i in 1..<chain.count {
            if chain[i].isFixed { 
                // Keep fixed joints at their original positions
                chain[i].position = originalPositions[i]
                continue 
            }
            let dir = simd_normalize(chain[i].position - chain[i - 1].position)
            chain[i].position = chain[i - 1].position + dir * boneLengths[i - 1]
        }
        
        // Backward pass to ensure bone lengths are maintained
        for i in stride(from: chain.count - 2, through: 0, by: -1) {
            if chain[i].isFixed { 
                // Keep fixed joints at their original positions
                chain[i].position = originalPositions[i]
                continue 
            }
            let dir = simd_normalize(chain[i].position - chain[i + 1].position)
            chain[i].position = chain[i + 1].position + dir * boneLengths[i]
        }
        
        // Apply angle constraints
        applyAngleConstraints(chain: chain)
        
        // Final validation: ensure all bone lengths are exactly correct
        for i in 1..<chain.count {
            if chain[i].isFixed { continue }
            let currentLength = simd_distance(chain[i].position, chain[i - 1].position)
            let expectedLength = boneLengths[i - 1]
            
            // If length deviation is significant, correct it
            if abs(currentLength - expectedLength) > 0.001 {
                let dir = simd_normalize(chain[i].position - chain[i - 1].position)
                chain[i].position = chain[i - 1].position + dir * expectedLength
            }
        }
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

// MARK: - Serializable Data Structures for Save/Load

struct SkeletonData: Codable {
    let id: String
    let name: String
    let rootJointId: String?
    let joints: [JointData]
    let bones: [BoneData]
    let pixelArts: [PixelArtDataCodable]
    
    init(from skeleton: Skeleton) {
        self.id = skeleton.id.uuidString
        self.name = skeleton.name
        self.rootJointId = skeleton.rootJoint?.id.uuidString
        self.joints = skeleton.joints.map { $0.data }
        self.bones = skeleton.bones.map { $0.data }
        self.pixelArts = skeleton.pixelArts.map { $0.codable }
    }
}

struct JointData: Codable {
    let id: String
    let name: String
    let position: Vector2Data
    let rotation: Float
    let isFixed: Bool
    let minAngle: Float
    let maxAngle: Float
    let hasAngleConstraints: Bool
    
    init(from joint: Joint) {
        self.id = joint.id.uuidString
        self.name = joint.name
        self.position = Vector2Data(x: joint.position.x, y: joint.position.y)
        self.rotation = joint.rotation
        self.isFixed = joint.isFixed
        self.minAngle = joint.minAngle
        self.maxAngle = joint.maxAngle
        self.hasAngleConstraints = joint.hasAngleConstraints
    }
}

struct BoneData: Codable {
    let id: String
    let name: String
    let startJointId: String
    let endJointId: String
    let thickness: Float
    let color: ColorData
    let originalLength: Float?
    let pixelArtId: String?
    let pixelArtScale: Float?
    let pixelArtRotation: Float?
    
    init(from bone: Bone) {
        self.id = bone.id.uuidString
        self.name = bone.name
        self.startJointId = bone.startJoint.id.uuidString
        self.endJointId = bone.endJoint.id.uuidString
        self.thickness = bone.thickness
        self.color = ColorData(from: bone.color)
        self.originalLength = bone.originalLength
        self.pixelArtId = bone.pixelArt?.id.uuidString
        self.pixelArtScale = bone.pixelArtScale
        self.pixelArtRotation = bone.pixelArtRotation
    }
}

struct Vector2Data: Codable {
    let x: Float
    let y: Float
}

struct ColorData: Codable {
    let r: Float
    let g: Float
    let b: Float
    let a: Float
    
    init(from color: NSColor) {
        let rgbColor = color.usingColorSpace(.sRGB) ?? color
        self.r = Float(rgbColor.redComponent)
        self.g = Float(rgbColor.greenComponent)
        self.b = Float(rgbColor.blueComponent)
        self.a = Float(rgbColor.alphaComponent)
    }
    
    func toNSColor() -> NSColor {
        return NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
}

struct PixelArtDataCodable: Codable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    let anchorPoint: Vector2Data
    let imageData: String // Base64 encoded image data
    
    init(from pixelArt: PixelArtData) {
        self.id = pixelArt.id.uuidString
        self.name = pixelArt.name
        self.width = pixelArt.width
        self.height = pixelArt.height
        self.anchorPoint = Vector2Data(x: pixelArt.anchorPoint.x, y: pixelArt.anchorPoint.y)
        self.imageData = PixelArtDataCodable.encodePixelsToBase64(pixelArt.pixels)
    }
    
    func toPixelArtData() -> PixelArtData? {
        guard let id = UUID(uuidString: id) else { return nil }
        var pixelArt = PixelArtData(id: id, name: name, width: width, height: height)
        pixelArt.anchorPoint = simd_float2(anchorPoint.x, anchorPoint.y)
        pixelArt.pixels = PixelArtDataCodable.decodePixelsFromBase64(imageData, width: width, height: height)
        return pixelArt
    }
    
    private static func encodePixelsToBase64(_ pixels: [[NSColor?]]) -> String {
        var data = Data()
        
        for row in pixels {
            for pixel in row {
                if let color = pixel {
                    let rgbColor = color.usingColorSpace(.sRGB) ?? color
                    let r = UInt8(rgbColor.redComponent * 255)
                    let g = UInt8(rgbColor.greenComponent * 255)
                    let b = UInt8(rgbColor.blueComponent * 255)
                    let a = UInt8(rgbColor.alphaComponent * 255)
                    data.append(contentsOf: [r, g, b, a])
                } else {
                    // Transparent pixel
                    data.append(contentsOf: [0, 0, 0, 0])
                }
            }
        }
        
        return data.base64EncodedString()
    }
    
    private static func decodePixelsFromBase64(_ base64String: String, width: Int, height: Int) -> [[NSColor?]] {
        guard let data = Data(base64Encoded: base64String) else {
            return Array(repeating: Array(repeating: nil, count: width), count: height)
        }
        
        var pixels: [[NSColor?]] = Array(repeating: Array(repeating: nil, count: width), count: height)
        let bytesPerPixel = 4 // RGBA
        
        for row in 0..<height {
            for col in 0..<width {
                let pixelIndex = (row * width + col) * bytesPerPixel
                
                if pixelIndex + 3 < data.count {
                    let r = CGFloat(data[pixelIndex]) / 255.0
                    let g = CGFloat(data[pixelIndex + 1]) / 255.0
                    let b = CGFloat(data[pixelIndex + 2]) / 255.0
                    let a = CGFloat(data[pixelIndex + 3]) / 255.0
                    
                    if a > 0 { // Only create color if not transparent
                        pixels[row][col] = NSColor(red: r, green: g, blue: b, alpha: a)
                    }
                }
            }
        }
        
        return pixels
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
