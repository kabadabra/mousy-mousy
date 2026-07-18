import Testing
@testable import MousyCore

@Test func speedMultipliers() {
    #expect(MoveSpeed.sleepy.multiplier == 0.5)
    #expect(MoveSpeed.normal.multiplier == 1.0)
    #expect(MoveSpeed.frisky.multiplier == 1.8)
    #expect(MoveSpeed.sleepy.displayName == "Sleepy")
}

@Test func patternChoiceMapsToSchedulerMode() {
    #expect(PatternChoice.auto.schedulerMode == .autoCycle)
    #expect(PatternChoice.zoomies.schedulerMode == .fixed(.zoomies))
    #expect(PatternChoice.figureEight.schedulerMode == .fixed(.figureEight))
    #expect(PatternChoice.auto.displayName == "Auto-cycle")
    #expect(PatternChoice.figureEight.displayName == "Figure-8")
    #expect(PatternChoice.allCases.count == 6)
}

@Test func rawValuesRoundTripForAppStorage() {
    for c in PatternChoice.allCases { #expect(PatternChoice(rawValue: c.rawValue) == c) }
    for s in MoveSpeed.allCases { #expect(MoveSpeed(rawValue: s.rawValue) == s) }
    for b in BackdropStyle.allCases { #expect(BackdropStyle(rawValue: b.rawValue) == b) }
}

@Test func backdropStylesMapToOpacityAndNames() {
    #expect(BackdropStyle.subtle.scrimOpacity == 0.12)
    #expect(BackdropStyle.dim.scrimOpacity == 0.70)
    #expect(BackdropStyle.dark.scrimOpacity == 0.92)
    #expect(BackdropStyle.subtle.displayName == "Subtle")
    #expect(BackdropStyle.dim.displayName == "Dim")
    #expect(BackdropStyle.dark.displayName == "Dark")
    #expect(BackdropStyle.allCases.count == 3)
}
