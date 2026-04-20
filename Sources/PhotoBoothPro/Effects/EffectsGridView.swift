import SwiftUI
import AVFoundation

struct EffectsGridView: View {
    @Binding var selection: Effect
    let session: AVCaptureSession
    let isMirrored: Bool
    let onClose: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(Effect.allCases) { effect in
                        EffectTileView(
                            effect: effect,
                            isSelected: selection == effect,
                            liveSession: effect == .normal ? session : nil,
                            isMirrored: isMirrored
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selection = effect
                            }
                        }
                    }
                }
                .padding(28)
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.85), .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(14)
            .help("Close Effects (Esc)")
        }
        .background(.black.opacity(0.55))
        .background(.ultraThinMaterial)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
