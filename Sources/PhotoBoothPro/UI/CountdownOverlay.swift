import SwiftUI

/// Photo-Booth-style countdown bar. Sits along the bottom edge of the
/// preview and shows `3 2 1 📷`, highlighting whichever tick is current.
///
/// Drive `current` as the seconds remaining (3 → 2 → 1), then set to `0`
/// to flash the shutter icon right before firing.
struct CountdownOverlay: View {
    /// Seconds remaining, 3…1. Use 0 for the shutter-icon tick.
    let current: Int

    private let total = 3

    var body: some View {
        HStack(spacing: 34) {
            ForEach((1...total).reversed(), id: \.self) { n in
                digit(n)
            }
            shutter
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(red: 1.00, green: 0.38, blue: 0.30),
                         Color(red: 0.97, green: 0.45, blue: 0.34)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func digit(_ n: Int) -> some View {
        let active = n == current
        Text("\(n)")
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .foregroundStyle(active ? Color.white : Color.white.opacity(0.35))
            .scaleEffect(active ? 1.0 : 0.85)
            .shadow(color: .black.opacity(active ? 0.25 : 0), radius: 4, y: 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: active)
    }

    private var shutter: some View {
        let active = current <= 0
        return Image(systemName: "camera.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(active ? Color.white : Color.white.opacity(0.35))
            .scaleEffect(active ? 1.0 : 0.85)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: active)
    }
}
