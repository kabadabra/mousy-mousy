public enum MoveSpeed: String, CaseIterable, Sendable {
    case sleepy, normal, frisky

    public var multiplier: Double {
        switch self {
        case .sleepy: 0.5
        case .normal: 1.0
        case .frisky: 1.8
        }
    }

    public var displayName: String {
        switch self {
        case .sleepy: "Sleepy"
        case .normal: "Normal"
        case .frisky: "Frisky"
        }
    }
}

public enum PatternChoice: String, CaseIterable, Sendable {
    case auto, circle, star, figureEight, scribble, zoomies

    public var schedulerMode: PatternScheduler.Mode {
        switch self {
        case .auto: .autoCycle
        case .circle: .fixed(.circle)
        case .star: .fixed(.star)
        case .figureEight: .fixed(.figureEight)
        case .scribble: .fixed(.scribble)
        case .zoomies: .fixed(.zoomies)
        }
    }

    public var displayName: String {
        switch self {
        case .auto: "Auto-cycle"
        case .circle: PatternKind.circle.displayName
        case .star: PatternKind.star.displayName
        case .figureEight: PatternKind.figureEight.displayName
        case .scribble: PatternKind.scribble.displayName
        case .zoomies: PatternKind.zoomies.displayName
        }
    }
}
