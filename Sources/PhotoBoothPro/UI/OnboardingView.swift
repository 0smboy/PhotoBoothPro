import SwiftUI
import AppKit

/// First-run / AI-unavailable sheet. Collects an OpenRouter API key and drops
/// it into a local plist file, or points the user at codex CLI as a fallback.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var showing = false

    var onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock AI effects")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Paste an OpenRouter API key to enable Ghibli / Anime / Oil / Pixel transforms.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("OpenRouter API Key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showing {
                            TextField("sk-or-v1-…", text: $apiKey)
                        } else {
                            SecureField("sk-or-v1-…", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    Button { showing.toggle() } label: {
                        Image(systemName: showing ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12)))

                Link("Get a key at openrouter.ai/keys",
                     destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.system(size: 11))

                Text("Saved at ~/Library/Application Support/PhotoBoothPro/config.plist (chmod 0600). Uses `google/gemini-2.5-flash-image` — ~10-15s per edit.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Don't have one?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Real-time filters (Mono, Noir, Chrome, Thermal, X-Ray, Comic, etc.) work without any key. AI styles show up behind the **Advanced** toggle in the Effects panel.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Skip") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onSave(trimmed)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 480)
    }
}
