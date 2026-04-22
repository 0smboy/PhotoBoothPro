import Foundation

/// Local storage for the OpenRouter API key.
///
/// We intentionally do NOT use the macOS Keychain here. For ad-hoc-signed
/// dev builds, every `xcodebuild` produces a new code signature, and the
/// Keychain treats each new signature as a different app — so every launch
/// triggers the "wants to use confidential information" password dialog.
/// Obnoxious for a local-first tool where the key already lives on disk.
///
/// Instead we write a plist under
/// `~/Library/Application Support/PhotoBoothPro/config.plist`, chmod 0o600.
/// Anyone who can read that file already has full access to the user account.
/// `$OPENROUTER_API_KEY` in the environment still wins when present.
enum APIKeyStore {
    static let envVarName = "OPENROUTER_API_KEY"

    private static let directoryURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("PhotoBoothPro", isDirectory: true)
    }()

    private static let fileURL: URL =
        directoryURL.appendingPathComponent("config.plist")

    // MARK: - Public

    static func load() -> String? {
        if let env = ProcessInfo.processInfo.environment[envVarName],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        return loadFromFile()
    }

    /// Read key from the plist file, ignoring env. Used by Settings UI.
    static func loadFromFile() -> String? {
        guard
            let data = try? Data(contentsOf: fileURL),
            let plist = try? PropertyListSerialization
                .propertyList(from: data, options: [], format: nil) as? [String: Any],
            let key = plist["openrouterKey"] as? String,
            !key.isEmpty
        else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            var plist = (try? PropertyListSerialization.propertyList(
                from: (try? Data(contentsOf: fileURL)) ?? Data(),
                options: [], format: nil
            ) as? [String: Any]) ?? [:]
            plist["openrouterKey"] = key
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            )
            try data.write(to: fileURL, options: [.atomic])
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func delete() -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return true }
        do {
            var plist = (try? PropertyListSerialization.propertyList(
                from: Data(contentsOf: fileURL), options: [], format: nil
            ) as? [String: Any]) ?? [:]
            plist.removeValue(forKey: "openrouterKey")
            if plist.isEmpty {
                try FileManager.default.removeItem(at: fileURL)
            } else {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: plist, format: .xml, options: 0
                )
                try data.write(to: fileURL, options: [.atomic])
            }
            return true
        } catch {
            return false
        }
    }

    enum Source: String { case env, file, none }

    static func currentSource() -> Source {
        if let v = ProcessInfo.processInfo.environment[envVarName],
           !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .env
        }
        return loadFromFile() != nil ? .file : .none
    }
}
