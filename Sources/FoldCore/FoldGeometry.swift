import Foundation

/// Signed fold: closing is positive, opening past the calibrated angle is negative.
public struct FoldMapping {
    public var reference: Double
    public var travel: Double
    public var deadZone: Double

    public init(reference: Double = 90, travel: Double = 60, deadZone: Double = 1) {
        self.reference = reference
        self.travel = travel
        self.deadZone = deadZone
    }

    public func progress(angle: Double) -> Double {
        guard angle.isFinite, reference.isFinite, travel.isFinite, travel > deadZone,
              deadZone >= 0 else { return 0 }
        let delta = reference - angle
        let magnitude = max(0, abs(delta) - deadZone) / (travel - deadZone)
        return (delta < 0 ? -1 : 1) * min(1, magnitude)
    }
}

public enum LidReport {
    /// Standard Apple HID feature report 1: identifier, degrees low byte, high byte.
    /// Do not interpret arbitrary vendor sensor reports as an angle.
    public static func angle(bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3, bytes[0] == 1 else { return nil }
        let value = Int(bytes[1]) | Int(bytes[2]) << 8
        guard (0...180).contains(value) else { return nil }
        return Double(value)
    }
}

/// Suppresses sub-degree jitter without a time-based animation that keeps running after the lid stops.
public struct AngleLatch {
    public private(set) var value: Double?
    public init() {}
    public mutating func update(_ angle: Double) -> Double {
        guard angle.isFinite else { return value ?? 90 }
        if value == nil || abs(angle - value!) >= 0.5 { value = angle }
        return value!
    }
}

/// Full-height curved desktop; the bottom remains anchored at the hinge.
public struct FoldPose {
    public let progress: Double
    public var intensity: Double { abs(progress) }

    public init(progress: Double) {
        self.progress = progress.isFinite ? max(-1, min(1, progress)) : 0
    }

    /// Inverse vertical mapping, normalized bottom to top. Both edges stay fixed.
    public func sourceHeight(at height: Double) -> Double {
        let y = max(0, min(1, height))
        return y + progress * 0.32 * y * (1 - y)
    }

    public func width(at height: Double) -> Double {
        let y = max(0, min(1, height))
        let depth = progress >= 0 ? y : 1 - y
        return 1 - 0.24 * intensity * depth * depth
    }
}
