import SwiftUI

/// A tile in the Effects grid. For local CIFilter effects the tile shows a
/// live, filter-previewed feed of the camera; for AI effects it shows a
/// gradient + icon (since we can't preview those without calling the API).
struct EffectTileView: View {
    let effect: Effect
    let isSelected: Bool
    let camera: CameraManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                tileBackground
                tileLabel
            }
            .aspectRatio(4.0/3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? effect.accentColor : .white.opacity(0.06),
                            lineWidth: isSelected ? 3 : 1)
            )
            .shadow(color: isSelected ? effect.accentColor.opacity(0.35) : .clear,
                    radius: isSelected ? 8 : 0)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tileBackground: some View {
        switch effect {
        case .local(let f):
            TileLivePreview(camera: camera, filter: f)
                .allowsHitTesting(false)
        case .ai(let s):
            ZStack {
                LinearGradient(
                    colors: [s.accentColor, s.accentColor.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: s.symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
            }
        }
    }

    private var tileLabel: some View {
        HStack(spacing: 4) {
            if case .ai = effect {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(effect.displayName)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.black.opacity(0.55)))
        .padding(6)
    }
}

/// Small NSViewRepresentable wrapper around `FilteredMetalPreview` that
/// pins one specific local filter per tile, independent of the main preview.
private struct TileLivePreview: NSViewRepresentable {
    let camera: CameraManager
    let filter: LocalFilter

    func makeNSView(context: Context) -> FilteredMetalPreview {
        let v = FilteredMetalPreview()
        v.aspectMode = .fill
        v.configure(camera: camera, resolver: .specific(filter))
        return v
    }

    func updateNSView(_ nsView: FilteredMetalPreview, context: Context) {
        nsView.configure(camera: camera, resolver: .specific(filter))
    }
}
