import SwiftUI

/// Segmented 2-state toggle for camera mirroring.
/// - Natural (default): WYSIWYG — you see yourself as others see you (non-mirrored).
/// - Mirror: classic Photo Booth — preview and saved photo both flipped horizontally.
struct MirrorModeToggle: View {
    @Binding var isMirrored: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment(
                icon: "person.crop.square",
                label: "Natural",
                active: !isMirrored
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isMirrored = false
                }
            }
            segment(
                icon: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill",
                label: "Mirror",
                active: isMirrored
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isMirrored = true
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.06)))
        )
        .help(isMirrored
              ? "Mirror mode: preview and photos are flipped (Photo Booth style)"
              : "Natural mode: preview and photos match how others see you")
    }

    @ViewBuilder
    private func segment(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
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
        .help(label)
    }
}
