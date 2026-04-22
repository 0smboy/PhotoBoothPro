import SwiftUI

/// Segmented Photo / Video picker modeled after Photo Booth's left-side
/// mode selector (icons only, pill highlight on the active one).
struct CaptureModeToggle: View {
    @Binding var mode: CaptureMode
    /// Disable while a recording is in progress — can't swap modes mid-capture.
    var isLocked: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            segment(.photo)
            segment(.video)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.06)))
        )
        .opacity(isLocked ? 0.4 : 1.0)
        .allowsHitTesting(!isLocked)
    }

    @ViewBuilder
    private func segment(_ m: CaptureMode) -> some View {
        let active = mode == m
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                mode = m
            }
        } label: {
            Image(systemName: m.symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 28)
                .foregroundStyle(active ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(active ? Color.accentColor.opacity(0.35) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(m.label)
    }
}
