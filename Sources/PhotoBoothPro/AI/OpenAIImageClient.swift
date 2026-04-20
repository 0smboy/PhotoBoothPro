import Foundation

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidImage
    case httpError(Int, String)
    case malformedResponse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:        return "OpenAI API key is not set. Open Settings to add one."
        case .invalidImage:         return "Could not encode the captured image."
        case .httpError(let c, let m): return "OpenAI error \(c): \(m)"
        case .malformedResponse:    return "Unexpected response from OpenAI."
        case .network(let e):       return "Network error: \(e.localizedDescription)"
        }
    }
}

struct OpenAIImageClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Apply a style transformation to `imageData` (PNG bytes) using gpt-image-1.
    /// Returns the transformed PNG bytes.
    func edit(imageData: Data, prompt: String, size: String = "1024x1024") async throws -> Data {
        guard let apiKey = APIKeyStore.load() else {
            throw OpenAIError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/images/edits")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        let body = Self.buildMultipartBody(
            boundary: boundary,
            fields: [
                "model": "gpt-image-1",
                "prompt": prompt,
                "n": "1",
                "size": size
            ],
            imageData: imageData,
            imageField: "image",
            imageFilename: "capture.png",
            imageMime: "image/png"
        )
        request.timeoutInterval = 120

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.upload(for: request, from: body)
        } catch {
            throw OpenAIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.malformedResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let msg = Self.extractErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw OpenAIError.httpError(http.statusCode, msg)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let arr = json["data"] as? [[String: Any]],
            let first = arr.first,
            let b64 = first["b64_json"] as? String,
            let result = Data(base64Encoded: b64)
        else {
            throw OpenAIError.malformedResponse
        }
        return result
    }

    private static func buildMultipartBody(
        boundary: String,
        fields: [String: String],
        imageData: Data,
        imageField: String,
        imageFilename: String,
        imageMime: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        for (name, value) in fields {
            body.appendString("--\(boundary)\(crlf)")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
            body.appendString("\(value)\(crlf)")
        }

        body.appendString("--\(boundary)\(crlf)")
        body.appendString(
            "Content-Disposition: form-data; name=\"\(imageField)\"; filename=\"\(imageFilename)\"\(crlf)"
        )
        body.appendString("Content-Type: \(imageMime)\(crlf)\(crlf)")
        body.append(imageData)
        body.appendString(crlf)
        body.appendString("--\(boundary)--\(crlf)")
        return body
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let err = json["error"] as? [String: Any],
            let message = err["message"] as? String
        else { return nil }
        return message
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}
