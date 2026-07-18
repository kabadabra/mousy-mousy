import CoreGraphics
import Foundation

public enum Geometry {
    /// Cocoa global (bottom-left origin) → CG global (top-left origin).
    /// Flip is about the PRIMARY screen's height, never the current screen's.
    public static func cgFromCocoa(_ p: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: p.x, y: primaryScreenHeight - p.y)
    }

    /// Cocoa global point → local point for a view exactly filling `screenFrame`
    /// (SwiftUI/AppKit-flipped top-left origin).
    public static func viewFromCocoa(_ p: CGPoint, screenFrame: CGRect) -> CGPoint {
        CGPoint(x: p.x - screenFrame.minX, y: screenFrame.maxY - p.y)
    }

    public static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
