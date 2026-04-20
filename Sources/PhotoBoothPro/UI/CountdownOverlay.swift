import SwiftUI

struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 160, height: 160)
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 2))
            Text("\(value)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 3)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
