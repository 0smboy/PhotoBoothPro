import Foundation

/// High-level entry point the UI uses to run AI image edits. Picks the best
/// available backend so callers don't care about transport.
///
///  * If an OpenRouter key is available (env var or on-disk config) we call
///    OpenRouter's chat/completions (Gemini 2.5 Flash Image / Nano-Banana).
///    Fast (~5-15s) and directly edits without an agent loop.
///  * Otherwise we fall back to spawning the local `codex` CLI.
struct ImageEditService {
    enum Backend: String { case openRouter, codex, none }

    static func currentBackend() -> Backend {
        if APIKeyStore.load() != nil { return .openRouter }
        if CodexAvailability.isInstalled() { return .codex }
        return .none
    }

    static func currentBackendLabel() -> String {
        switch currentBackend() {
        case .openRouter:
            switch APIKeyStore.currentSource() {
            case .env:      return "OpenRouter (env var)"
            case .file:     return "OpenRouter (saved)"
            case .none:     return "OpenRouter"
            }
        case .codex:
            return "codex CLI (slow fallback)"
        case .none:
            return "Not configured"
        }
    }

    static func isAvailable() -> Bool { currentBackend() != .none }

    /// Apply `prompt` to `imageData` and return edited PNG bytes.
    static func edit(imageData: Data, prompt: String) async throws -> Data {
        switch currentBackend() {
        case .openRouter:
            return try await OpenRouterImageClient().edit(imageData: imageData, prompt: prompt)
        case .codex:
            return try await CodexImageClient().edit(imageData: imageData, prompt: prompt)
        case .none:
            throw OpenRouterError.missingAPIKey
        }
    }
}
