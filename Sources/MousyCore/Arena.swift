import CoreGraphics

/// One display's playable area: the full screen rect (for cursor-safe routing
/// between displays) and the inset rect patterns run inside.
public struct Arena: Sendable, Equatable {
    public let screen: CGRect
    public let inset: CGRect

    public init(screen: CGRect, inset: CGRect) {
        self.screen = screen
        self.inset = inset
    }

    public init(screen: CGRect, margin: CGFloat = 80) {
        self.init(screen: screen, inset: screen.insetBy(dx: margin, dy: margin))
    }
}

public enum ArenaRouting {
    /// Cursor-safe waypoint for a scamper between two screens. Screens sharing
    /// an edge get the midpoint of the shared segment — straight legs to/from
    /// it stay inside the two convex screen rects, so neither Mousy nor the
    /// cursor ever crosses a dead zone. Corner-touch arrangements fall back to
    /// the midpoint of the closest-point pair (best effort).
    public static func waypoint(from a: CGRect, to b: CGRect) -> CGPoint {
        let tol: CGFloat = 1
        // Vertical shared edge (side-by-side).
        if abs(a.maxX - b.minX) <= tol || abs(b.maxX - a.minX) <= tol {
            let x = abs(a.maxX - b.minX) <= tol ? (a.maxX + b.minX) / 2 : (b.maxX + a.minX) / 2
            let lo = max(a.minY, b.minY), hi = min(a.maxY, b.maxY)
            if hi > lo { return CGPoint(x: x, y: (lo + hi) / 2) }
        }
        // Horizontal shared edge (stacked).
        if abs(a.maxY - b.minY) <= tol || abs(b.maxY - a.minY) <= tol {
            let y = abs(a.maxY - b.minY) <= tol ? (a.maxY + b.minY) / 2 : (b.maxY + a.minY) / 2
            let lo = max(a.minX, b.minX), hi = min(a.maxX, b.maxX)
            if hi > lo { return CGPoint(x: (lo + hi) / 2, y: y) }
        }
        // Fallback: midpoint of the closest-point pair.
        let pa = CGPoint(x: min(max(b.midX, a.minX), a.maxX),
                         y: min(max(b.midY, a.minY), a.maxY))
        let pb = CGPoint(x: min(max(pa.x, b.minX), b.maxX),
                         y: min(max(pa.y, b.minY), b.maxY))
        return CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
    }
}
