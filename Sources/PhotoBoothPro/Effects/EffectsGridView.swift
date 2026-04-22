import SwiftUI

struct EffectsGridView: View {
    @Binding var selection: Effect
    let camera: CameraManager
    let onClose: () -> Void

    @AppStorage("advancedAIEnabled") private var advancedAIEnabled: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    filtersSection
                    if advancedAIEnabled {
                        aiSection
                    }
                }
                .padding(24)
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.85), .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(14)
            .help("Close Effects (Esc)")
        }
        .background(.black.opacity(0.55))
        .background(.ultraThinMaterial)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var header: some View {
        HStack {
            Text("Effects")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Toggle(isOn: $advancedAIEnabled.animation(.easeInOut(duration: 0.2))) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("Advanced · AI")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.pink)
            .help("Enable slow, server-side AI style transfers")
        }
        .padding(.trailing, 40)   // leave room for the close button
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real-time filters")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(LocalFilter.allCases, id: \.self) { f in
                    let eff = Effect.local(f)
                    EffectTileView(
                        effect: eff,
                        isSelected: selection == eff,
                        camera: camera
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selection = eff
                        }
                    }
                }
            }
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("AI styles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                Text("— slow, runs at capture")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(AIStyle.allCases, id: \.self) { s in
                    let eff = Effect.ai(s)
                    EffectTileView(
                        effect: eff,
                        isSelected: selection == eff,
                        camera: camera
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selection = eff
                        }
                    }
                }
            }
        }
    }
}
