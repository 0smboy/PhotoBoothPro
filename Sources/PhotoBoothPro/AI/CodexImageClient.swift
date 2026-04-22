import Foundation

enum CodexError: LocalizedError {
    case codexNotFound
    case spawnFailed(String)
    case timeout
    case noOutput(lastMessage: String?)
    case codexFailed(Int32, String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "`codex` CLI not found. Install it (`npm i -g @openai/codex` or `brew install codex`) and run `codex login`."
        case .spawnFailed(let msg):
            return "Failed to launch codex: \(msg)"
        case .timeout:
            return "codex timed out producing an image."
        case .noOutput(let last):
            if let last, !last.isEmpty {
                return "codex finished without an image. Last message: \(last)"
            }
            return "codex finished without producing an image."
        case .codexFailed(let code, let msg):
            let trimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "codex exited with status \(code)."
            }
            return "codex exited with status \(code): \(trimmed)"
        case .readFailed(let path):
            return "Could not read generated image at \(path)."
        }
    }
}

/// Drives image generation via the local `codex` CLI. The app never handles an
/// API key directly — whatever auth the user has set up for `codex` (ChatGPT
/// login, env `OPENAI_API_KEY`, etc.) is what gets used.
struct CodexImageClient {

    /// How long we'll wait for codex to produce an output.png before giving up.
    var timeout: TimeInterval = 300

    /// Optional absolute path to the `codex` executable. When nil, we probe a
    /// few common install locations.
    var executablePath: String?

    /// Apply `prompt` to `imageData` and return the transformed PNG bytes.
    func edit(imageData: Data, prompt: String) async throws -> Data {
        let codex = try resolveCodexPath()

        // Per-invocation working directory. codex is instructed to write
        // `output.png` here; we read it back afterwards.
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("photoboothpro-codex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let inputURL = workDir.appendingPathComponent("input.png")
        let outputURL = workDir.appendingPathComponent("output.png")
        try imageData.write(to: inputURL)

        let instructions = Self.buildInstructions(userPrompt: prompt, outputPath: outputURL.path)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: codex)
            process.currentDirectoryURL = workDir
            process.arguments = [
                "exec",
                "--json",
                "--skip-git-repo-check",
                "--sandbox", "workspace-write",
                "--dangerously-bypass-approvals-and-sandbox",
                // Agent-reasoning knobs: we only want the CLI to dispatch the
                // image-edit tool as fast as possible, not "think" about it.
                "-c", "model_reasoning_effort=minimal",
                "-m", "gpt-5-codex-mini",
                "--cd", workDir.path,
                "-i", inputURL.path,
                "--",
                instructions,
            ]

            // Forward the user's shell env so codex picks up OPENAI_API_KEY /
            // HOME / its own credentials at ~/.codex. We also prepend a few
            // well-known bin dirs (including the directory that actually holds
            // `codex`) to PATH so the `#!/usr/bin/env node` shebang can find
            // `node` — GUI apps don't inherit the user's shell PATH.
            var env = ProcessInfo.processInfo.environment
            if env["HOME"] == nil {
                env["HOME"] = NSHomeDirectory()
            }
            env["PATH"] = Self.augmentedPath(codexPath: codex, existing: env["PATH"])
            process.environment = env

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let state = StreamState()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                state.appendStdout(chunk)
            }

            stderr.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { return }
                state.appendStderr(chunk)
            }

            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                let status = proc.terminationStatus
                let lastMessage = state.lastAgentMessage()

                // Even if codex exited non-zero, prefer returning the file if it exists.
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    if let data = try? Data(contentsOf: outputURL) {
                        cont.resume(returning: data)
                        return
                    }
                    cont.resume(throwing: CodexError.readFailed(outputURL.path))
                    return
                }

                if status != 0 {
                    let stderrText = state.stderrString()
                    cont.resume(throwing: CodexError.codexFailed(status, lastMessage ?? stderrText))
                    return
                }

                cont.resume(throwing: CodexError.noOutput(lastMessage: lastMessage))
            }

            do {
                try process.run()
            } catch {
                cont.resume(throwing: CodexError.spawnFailed(error.localizedDescription))
                return
            }

            // Timeout guard.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }

    // MARK: - Prompt

    private static func buildInstructions(userPrompt: String, outputPath: String) -> String {
        """
        You are a photo-stylization agent. An input image is attached and is also \
        available on disk as `input.png` inside the current working directory.

        Task: produce a stylized version of that image according to this style brief, \
        preserving the subject's identity, pose, and composition:

        \(userPrompt)

        Requirements:
        - Generate one 1024×1024 PNG.
        - Save the final image to the absolute path: \(outputPath)
        - Do not ask for clarification, do not ask for confirmation, do not open any \
          interactive prompts. Make reasonable defaults and finish.
        - When the file exists at that exact path, reply with the single word DONE \
          and stop.
        """
    }

    // MARK: - PATH handling

    /// Builds a PATH that contains (a) the directory holding `codex` itself —
    /// which for a mise/nvm node install also contains `node` — plus common
    /// bin locations, followed by whatever the parent process had.
    private static func augmentedPath(codexPath: String, existing: String?) -> String {
        var dirs: [String] = []
        let codexDir = (codexPath as NSString).deletingLastPathComponent
        if !codexDir.isEmpty { dirs.append(codexDir) }

        let home = NSHomeDirectory()
        dirs.append(contentsOf: [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "\(home)/.local/bin",
        ])

        if let existing, !existing.isEmpty {
            dirs.append(existing)
        }

        // Dedupe while preserving order.
        var seen = Set<String>()
        let unique = dirs.filter { seen.insert($0).inserted }
        return unique.joined(separator: ":")
    }

    // MARK: - Executable lookup

    private func resolveCodexPath() throws -> String {
        if let provided = executablePath,
           FileManager.default.isExecutableFile(atPath: provided) {
            return provided
        }
        if let path = CodexAvailability.installedPath() {
            return path
        }
        throw CodexError.codexNotFound
    }

    // MARK: - Streaming bookkeeping

    /// Thread-safe scratch space for stdout/stderr accumulation + progress extraction.
    private final class StreamState: @unchecked Sendable {
        private let lock = NSLock()
        private var stdoutBuffer = Data()
        private var stderrBuffer = Data()
        private var carry = ""
        private var lastMessage: String?

        func appendStdout(_ chunk: Data) {
            lock.lock()
            stdoutBuffer.append(chunk)
            lock.unlock()

            // Streamed JSONL parsing — split on newlines, keep partial line in `carry`.
            if let text = String(data: chunk, encoding: .utf8) {
                lock.lock()
                carry += text
                var scan = carry
                carry = ""
                while let range = scan.range(of: "\n") {
                    let line = String(scan[..<range.lowerBound])
                    scan.removeSubrange(..<range.upperBound)
                    parseLine(line)
                }
                carry = scan
                lock.unlock()
            }
        }

        func appendStderr(_ chunk: Data) {
            lock.lock()
            stderrBuffer.append(chunk)
            lock.unlock()
        }

        func lastAgentMessage() -> String? {
            lock.lock(); defer { lock.unlock() }
            return lastMessage
        }

        func stderrString() -> String {
            lock.lock(); defer { lock.unlock() }
            return String(data: stderrBuffer, encoding: .utf8) ?? ""
        }

        /// Pull useful status text out of codex's JSONL event stream.
        private func parseLine(_ line: String) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            // Event shape: { "type": "item.completed", "item": { "type": "agent_message", "text": "..." } }
            if let item = obj["item"] as? [String: Any],
               let itemType = item["type"] as? String,
               itemType == "agent_message",
               let text = item["text"] as? String,
               !text.isEmpty {
                lastMessage = text
            }
        }
    }
}
