import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = APIKeyStore.loadFromFile() ?? ""
    @State private var showing = false
    @State private var saved = false
    @State private var backendLabel: String = ImageEditService.currentBackendLabel()

    var body: some View {
        Form {
            Section("AI Backend") {
                LabeledContent("Active") {
                    Text(backendLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(ImageEditService.isAvailable() ? .green : .orange)
                }

                if APIKeyStore.currentSource() == .env {
                    Text("Using the `OPENROUTER_API_KEY` from your shell environment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Group {
                        if showing {
                            TextField("sk-or-v1-…", text: $apiKey)
                        } else {
                            SecureField("sk-or-v1-…", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                    Button { showing.toggle() } label: {
                        Image(systemName: showing ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Button("Save") {
                        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            APIKeyStore.delete()
                        } else {
                            APIKeyStore.save(trimmed)
                        }
                        saved = true
                        backendLabel = ImageEditService.currentBackendLabel()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }
                    .keyboardShortcut(.defaultAction)
                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 11))
                    }
                }

                Text("Stored at ~/Library/Application Support/PhotoBoothPro/config.plist (chmod 0600). Model: `openai/gpt-5.4-image-2`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Codex fallback") {
                LabeledContent("codex CLI") {
                    Text(CodexAvailability.statusDescription())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CodexAvailability.isInstalled() ? .green : .secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 320, alignment: .trailing)
                        .textSelection(.enabled)
                }
                Text("Used only when no OpenRouter key is configured. Much slower (2-5 min per image).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("PhotoBooth Pro 1.0 — Non-mirrored capture + real-time filters + AI style transfer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 400)
    }
}
