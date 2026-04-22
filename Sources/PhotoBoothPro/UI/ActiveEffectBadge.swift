import SwiftUI

/// Small pill shown top-right of the preview when a non-identity effect is
/// active. Clicking the ✕ on the right clears the effect in one tap.
struct ActiveEffectBadge: View {
    let effect: Effect
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .bold))
            Text(effect.displayName)
                .font(.system(size: 11, weight: .semibold))
            Divider()
                .frame(height: 10)
                .overlay(.white.opacity(0.45))
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .contentShape(Rectangle())
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help("Clear effect")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(effect.accentColor.opacity(0.9)))
        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private var iconName: String {
        switch effect {
        case .ai:                return "sparkles"
        case .local(let f):
            return f.symbol
        }
    }
}
