import Foundation

enum OpenRouterError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case malformedResponse(String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenRouter API key is missing. Add one in Settings (or set $OPENROUTER_API_KEY)."
        case .httpError(let code, let msg):
            return "OpenRouter error \(code): \(msg)"
        case .malformedResponse(let why):
            return "Unexpected OpenRouter response: \(why)"
        case .network(let e):
            return "Network error: \(e.localizedDescription)"
        }
    }
}

/// Calls OpenRouter's `/chat/completions` with an image-capable model.
/// Default: `openai/gpt-5.4-image-2` (GPT-5.4 multimodal with GPT Image 2
/// generation). OpenRouter doesn't expose a separate `/images/edits` endpoint
/// — image edits go through chat completions with `modalities: ["image","text"]`.
struct OpenRouterImageClient {
    var model: String = "openai/gpt-5.4-image-2"
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Apply `prompt` to `imageData` (PNG bytes) and return the edited PNG.
    func edit(imageData: Data, prompt: String) async throws -> Data {
        guard let apiKey = APIKeyStore.load() else {
            throw OpenRouterError.missingAPIKey
        }

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Recommended by OpenRouter for attribution; harmless if absent.
        request.setValue("PhotoBoothPro", forHTTPHeaderField: "X-Title")
        request.setValue("https://github.com/photoboothpro", forHTTPHeaderField: "HTTP-Referer")

        let dataURL = "data:image/png;base64,\(imageData.base64EncodedString())"

        let body: [String: Any] = [
            "model": model,
            "modalities": ["image", "text"],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": dataURL]]
                ]
            ]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenRouterError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenRouterError.malformedResponse("not HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw OpenRouterError.httpError(http.statusCode, msg)
        }

        return try Self.extractImageData(from: data)
    }

    // MARK: - Parsing

    /// Response shape:
    /// {
    ///   "choices": [{ "message": {
    ///        "images": [{"type": "image_url",
    ///                    "image_url": {"url": "data:image/png;base64,..." }}],
    ///        "content": "..." } }]
    /// }
    private static func extractImageData(from data: Data) throws -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OpenRouterError.malformedResponse("not JSON")
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw OpenRouterError.malformedResponse("missing choices/message")
        }

        // Primary location: message.images[*].image_url.url
        if let images = message["images"] as? [[String: Any]] {
            for entry in images {
                if let urlField = entry["image_url"] as? [String: Any],
                   let urlStr = urlField["url"] as? String,
                   let decoded = decodeDataURL(urlStr) {
                    return decoded
                }
                if let urlStr = entry["url"] as? String,
                   let decoded = decodeDataURL(urlStr) {
                    return decoded
                }
            }
        }

        // Fallback: some providers embed the data URL in text content.
        if let text = message["content"] as? String,
           let decoded = decodeDataURL(text) {
            return decoded
        }

        throw OpenRouterError.malformedResponse("no image in response")
    }

    /// Accepts either a full `data:image/...;base64,XXX` URL or a bare base64
    /// blob, and returns decoded bytes (if the result looks like a PNG/JPEG).
    private static func decodeDataURL(_ s: String) -> Data? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("data:") {
            guard let commaIdx = trimmed.firstIndex(of: ",") else { return nil }
            let payload = String(trimmed[trimmed.index(after: commaIdx)...])
            return Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
        }
        // Heuristic: try to base64-decode; accept if it looks like an image.
        if let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters),
           looksLikeImage(data) {
            return data
        }
        return nil
    }

    private static func looksLikeImage(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        let b = [UInt8](data.prefix(8))
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return true }
        // JPEG: FF D8 FF
        if b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return true }
        // WebP (RIFF....WEBP)
        if b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46 { return true }
        return false
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = json["error"] as? [String: Any],
              let message = err["message"] as? String else {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(200)
                .description
        }
        return message
    }
}
