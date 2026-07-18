import CoreGraphics
import Foundation

/// A route Mousy runs. Positions are Cocoa global coordinates inside `bounds`.
/// `speed` is a multiplier (Sleepy 0.5 / Normal 1.0 / Frisky 1.8).
/// `cursor` is the current cursor position (used by ZoomiesPattern to flee).
public protocol MousePattern: Sendable {
    func startPoint(in bounds: CGRect) -> CGPoint
    mutating func step(dt: TimeInterval, bounds: CGRect, speed: Double, cursor: CGPoint) -> CGPoint
}
