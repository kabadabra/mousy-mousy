import CoreGraphics

/// Detects that the human moved the physical mouse while patterns were running.
public enum Deviation {
    public static let threshold: CGFloat = 15

    public static func humanMoved(expected: CGPoint, actual: CGPoint,
                                  threshold: CGFloat = Deviation.threshold) -> Bool {
        Geometry.distance(expected, actual) > threshold
    }
}
