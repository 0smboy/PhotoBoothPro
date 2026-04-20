import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = APIKeyStore.load() ?? ""
    @State private var showing = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("OpenAI") {
                HStack {
                    Group {
                        if showing {
                            TextField("sk-...", text: $apiKey)
                        } else {
                            SecureField("sk-...", text: $apiKey)
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                    }
                    .keyboardShortcut(.defaultAction)

                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 11))
                    }
                }

                Text("Stored securely in macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("PhotoBooth Pro 1.0 — Non-mirrored capture with AI effects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
    }
}
