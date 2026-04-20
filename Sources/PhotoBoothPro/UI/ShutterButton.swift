import SwiftUI

struct ShutterButton: View {
    let isBusy: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !isBusy else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false }
            }
            action()
        }) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 68, height: 68)
                Circle()
                    .fill(isBusy ? Color.gray : Color.red)
                    .frame(width: 54, height: 54)
                    .shadow(color: .red.opacity(isBusy ? 0 : 0.45), radius: 8, y: 2)
                Image(systemName: "camera.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(pressed ? 0.88 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .help(isBusy ? "Processing…" : "Take Photo (Space)")
    }
}
