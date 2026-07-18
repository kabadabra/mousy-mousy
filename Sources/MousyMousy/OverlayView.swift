import SwiftUI

/// Full-screen overlay content. The scrim is load-bearing: Liquid Glass samples
/// IN-WINDOW content, so without it the card renders flat on a clear window.
struct OverlayView: View {
    let model: OverlayModel
    let isCardScreen: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(model.scrimOpacity).ignoresSafeArea()
            if isCardScreen {
                EscCardView(model: model)
                if model.showSprite {
                    MousySpriteView(model: model)
                }
            }
        }
    }
}

struct EscCardView: View {
    let model: OverlayModel

    var body: some View {
        VStack(spacing: 14) {
            Text("🐭").font(.system(size: 42))
            switch model.phase {
            case .countdown(let n):
                Text("Starting in \(n)…")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
            case .running:
                Label("ESC to exit", systemImage: "escape")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(.primary)
        .padding(44)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .opacity(model.cardDimmed ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.6), value: model.cardDimmed)
    }
}

struct MousySpriteView: View {
    let model: OverlayModel

    var body: some View {
        Text("🐭")
            .font(.system(size: 40))
            // 🐭 faces left natively; mirror when running right.
            .scaleEffect(x: model.facingLeft ? 1 : -1, y: 1)
            .position(model.spriteViewPosition)
    }
}
