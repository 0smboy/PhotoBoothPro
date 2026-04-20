import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class PhotoStore {
    var items: [PhotoItem] = []
    var selectedID: UUID?

    private let outputDirectory: URL

    init() {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        self.outputDirectory = pictures.appendingPathComponent("PhotoBoothPro", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true
        )
    }

    var directoryURL: URL { outputDirectory }

    // MARK: - Public API

    /// Save a ready-to-disk PNG; returns the inserted item.
    @discardableResult
    func save(pngData: Data, effect: Effect) -> PhotoItem {
        let item = persistItem(pngData: pngData, effect: effect)
        items.insert(item, at: 0)
        selectedID = item.id
        return item
    }

    /// Insert a placeholder item (AI processing). Returns its id for later updates.
    func insertProcessing(effect: Effect, originalThumbnail: NSImage?) -> UUID {
        let item = PhotoItem(
            effect: effect,
            state: .processing,
            thumbnail: originalThumbnail
        )
        items.insert(item, at: 0)
        selectedID = item.id
        return item.id
    }

    /// Replace a placeholder item with final PNG data.
    func complete(id: UUID, pngData: Data) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let effect = items[idx].effect
        let url = writeFile(pngData: pngData, effect: effect)
        items[idx].url = url
        items[idx].state = .ready
        items[idx].thumbnail = NSImage(data: pngData)
    }

    func fail(id: UUID, message: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].state = .failed(message)
    }

    func remove(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        if let url = items[idx].url {
            try? FileManager.default.removeItem(at: url)
        }
        items.remove(at: idx)
        if selectedID == id { selectedID = items.first?.id }
    }

    func revealInFinder(id: UUID) {
        guard let url = items.first(where: { $0.id == id })?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyToClipboard(id: UUID) {
        guard
            let url = items.first(where: { $0.id == id })?.url,
            let image = NSImage(contentsOf: url)
        else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    // MARK: - Private

    private func persistItem(pngData: Data, effect: Effect) -> PhotoItem {
        let url = writeFile(pngData: pngData, effect: effect)
        return PhotoItem(
            url: url,
            effect: effect,
            state: .ready,
            thumbnail: NSImage(data: pngData)
        )
    }

    private func writeFile(pngData: Data, effect: Effect) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let name = "photoboothpro-\(formatter.string(from: Date()))-\(effect.fileSuffix).png"
        let url = outputDirectory.appendingPathComponent(name)
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
