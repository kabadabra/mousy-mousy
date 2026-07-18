public enum PatternKind: String, CaseIterable, Sendable {
    case circle, star, figureEight, scribble, zoomies

    public func makePattern(seed: UInt64) -> any MousePattern {
        switch self {
        case .circle: CirclePattern()
        case .star: StarPattern()
        case .figureEight: FigureEightPattern()
        case .scribble: ScribblePattern(seed: seed)
        case .zoomies: ZoomiesPattern(seed: seed)
        }
    }

    public var displayName: String {
        switch self {
        case .circle: "Circle"
        case .star: "Star"
        case .figureEight: "Figure-8"
        case .scribble: "Scribble"
        case .zoomies: "Zoomies"
        }
    }
}
