import SwiftUI

/// 3-state cycling button for flash mode: Off → Auto → On → Off.
struct FlashModeButton: View {
    @Binding var mode: FlashMode

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                mode = mode.next
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(background)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.06)))
            )
        }
        .buttonStyle(.plain)
        .help(mode.label)
    }

    private var label: String {
        switch mode {
        case .off:  return "Off"
        case .auto: return "Auto"
        case .on:   return "On"
        }
    }

    private var foreground: Color {
        switch mode {
        case .off:  return .secondary
        case .auto: return .primary
        case .on:   return .yellow
        }
    }

    private var background: Color {
        switch mode {
        case .off:  return .white.opacity(0.08)
        case .auto: return Color.accentColor.opacity(0.28)
        case .on:   return Color.yellow.opacity(0.28)
        }
    }
}
