import SwiftUI
import AVFoundation

/// A tile showing a preview of an effect. `.normal` hosts the live camera preview;
/// AI effects show a stylized static placeholder (pleasant gradient + icon) until
/// the user captures.
struct EffectTileView: View {
    let effect: Effect
    let isSelected: Bool
    let liveSession: AVCaptureSession?
    let isMirrored: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background: live feed for Normal, gradient stub for AI styles
                if effect == .normal, let session = liveSession {
                    CameraPreviewView(session: session, isMirrored: isMirrored)
                        .allowsHitTesting(false)
                } else {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: iconName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                }

                // Name banner
                VStack {
                    Spacer()
                    HStack {
                        Text(effect.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(.black.opacity(0.5))
                            )
                        Spacer()
                    }
                    .padding(6)
                }
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

    private var iconName: String {
        switch effect {
        case .normal:      return "person.crop.square"
        case .ghibli:      return "leaf.fill"
        case .anime:       return "sparkles"
        case .oilPainting: return "paintbrush.fill"
        case .pixelArt:    return "square.grid.4x3.fill"
        }
    }

    private var gradientColors: [Color] {
        switch effect {
        case .normal:
            return [.gray, .black]
        case .ghibli:
            return [Color(red: 0.62, green: 0.84, blue: 0.70),
                    Color(red: 0.33, green: 0.55, blue: 0.45)]
        case .anime:
            return [Color(red: 1.00, green: 0.60, blue: 0.82),
                    Color(red: 0.55, green: 0.37, blue: 0.88)]
        case .oilPainting:
            return [Color(red: 0.89, green: 0.64, blue: 0.35),
                    Color(red: 0.40, green: 0.18, blue: 0.10)]
        case .pixelArt:
            return [Color(red: 0.40, green: 0.78, blue: 1.00),
                    Color(red: 0.14, green: 0.30, blue: 0.65)]
        }
    }
}
