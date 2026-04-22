import SwiftUI

/// Toggle button that records a video when tapped, stops on the second tap.
/// Animates red → rounded square while recording, with a pulsing ring.
struct RecordButton: View {
    let isRecording: Bool
    let isDisabled: Bool
    let duration: TimeInterval?
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 58, height: 58)

                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.9), lineWidth: 3)
                        .frame(width: 58, height: 58)
                        .scaleEffect(pulse ? 1.06 : 1.0)
                        .opacity(pulse ? 0.25 : 0.85)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }

                shape
                    .fill(isDisabled ? Color.gray : Color.red)
                    .frame(
                        width:  isRecording ? 22 : 46,
                        height: isRecording ? 22 : 46
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
                    .shadow(color: .red.opacity(isDisabled ? 0 : 0.35), radius: 6, y: 2)
            }
            .overlay(alignment: .bottom) {
                if isRecording, let duration {
                    Text(format(duration))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .offset(y: 14)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(isRecording ? "Stop recording" : "Record video")
        .onAppear { pulse = isRecording }
        .onChange(of: isRecording) { _, newValue in pulse = newValue }
    }

    private var shape: some Shape {
        if isRecording {
            return AnyShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            return AnyShape(Circle())
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
