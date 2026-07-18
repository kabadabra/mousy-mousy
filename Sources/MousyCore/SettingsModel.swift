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

/// Overlay backdrop darkness while a session runs. Subtle keeps the desktop
/// visible; Dim and Dark are a night/privacy mode that hides screen content.
/// Never fully clear — the scrim also feeds the glass card's backdrop sampling.
public enum BackdropStyle: String, CaseIterable, Sendable {
    case subtle, dim, dark

    public var scrimOpacity: Double {
        switch self {
        case .subtle: 0.12
        case .dim: 0.70
        case .dark: 0.92
        }
    }

    public var displayName: String {
        switch self {
        case .subtle: "Subtle"
        case .dim: "Dim"
        case .dark: "Dark"
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
