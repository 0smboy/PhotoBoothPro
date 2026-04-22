import Foundation

/// Helpers that check whether the `codex` CLI is available on this machine.
/// Used by UI to decide whether to nudge the user towards installation.
enum CodexAvailability {
    /// Probes a handful of common install locations for `codex`.
    static func installedPath() -> String? {
        for path in candidatePaths() where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    static func isInstalled() -> Bool {
        installedPath() != nil
    }

    /// Short human-readable status string. Useful for SettingsView.
    static func statusDescription() -> String {
        if let path = installedPath() {
            return "Found at \(path)"
        }
        return "Not found — install codex CLI and run `codex login`."
    }

    private static func candidatePaths() -> [String] {
        var paths: [String] = []
        let home = NSHomeDirectory()
        paths.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.nvm/versions/node/current/bin/codex",
        ])
        let miseBase = "\(home)/.local/share/mise/installs/node"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: miseBase) {
            for v in versions {
                paths.append("\(miseBase)/\(v)/bin/codex")
            }
        }
        return paths
    }
}
