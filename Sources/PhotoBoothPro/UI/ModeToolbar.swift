import SwiftUI

enum CaptureMode: String, CaseIterable, Identifiable {
    case single, burst, effects
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .single:  return "square"
        case .burst:   return "square.grid.2x2"
        case .effects: return "sparkles"
        }
    }
}

struct ModeToolbar: View {
    @Binding var mode: CaptureMode
    var body: some View {
        HStack(spacing: 4) {
            ForEach(CaptureMode.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { mode = m }
                } label: {
                    Image(systemName: m.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 28)
                        .foregroundStyle(mode == m ? .primary : .secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(mode == m ? Color.accentColor.opacity(0.35) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.06)))
        )
    }
}
