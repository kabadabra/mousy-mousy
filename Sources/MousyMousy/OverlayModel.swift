import CoreGraphics
import Observation

@Observable @MainActor
final class OverlayModel {
    enum Phase: Equatable {
        case countdown(Int)
        case running
    }

    var phase: Phase = .countdown(3)
    var spriteViewPosition: CGPoint = .zero      // card panel's local (top-left) coords
    var facingLeft = true
    var showSprite = false
    var cardDimmed = false
    var scrimOpacity: Double = 0.12              // overridden per session from BackdropStyle

    func reset() {
        phase = .countdown(3)
        spriteViewPosition = .zero
        facingLeft = true
        showSprite = false
        cardDimmed = false
        scrimOpacity = 0.12
    }
}
