import Foundation
import AppKit
import AVFoundation
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
        loadFromDisk()
    }

    /// Hydrate the gallery with previously captured files in the output
    /// directory. Filenames look like
    /// `photoboothpro-yyyyMMdd-HHmmss-SSS-<effect>.{png,mov}`.
    /// Parses timestamp + effect, builds thumbnails, and inserts in
    /// reverse-chronological order.
    private func loadFromDisk() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: outputDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"

        var rebuilt: [PhotoItem] = []
        for url in entries {
            let ext = url.pathExtension.lowercased()
            let kind: MediaKind
            switch ext {
            case "png", "jpg", "jpeg": kind = .photo
            case "mov", "mp4", "m4v":  kind = .video
            default: continue
            }
            // Filename: photoboothpro-<ts>-<effect>.<ext>
            let stem = url.deletingPathExtension().lastPathComponent
            guard stem.hasPrefix("photoboothpro-") else { continue }
            let core = String(stem.dropFirst("photoboothpro-".count))
            // Timestamp portion is fixed-width: yyyyMMdd-HHmmss-SSS (18 chars).
            guard core.count > 19, core[core.index(core.startIndex, offsetBy: 18)] == "-" else { continue }
            let tsSubstring = core.prefix(18)
            let effectStr = String(core.dropFirst(19))

            let date = formatter.date(from: String(tsSubstring))
                ?? (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                ?? Date()

            let effect = Effect.from(fileSuffix: effectStr)
            let thumb = Self.thumbnail(for: url, kind: kind)

            rebuilt.append(PhotoItem(
                url: url,
                kind: kind,
                effect: effect,
                createdAt: date,
                state: .ready,
                thumbnail: thumb
            ))
        }
        rebuilt.sort { $0.createdAt > $1.createdAt }
        items = rebuilt
        selectedID = items.first?.id
    }

    private static func thumbnail(for url: URL, kind: MediaKind) -> NSImage? {
        switch kind {
        case .photo:
            // Downsample for the strip. Avoids loading 4K PNGs in full.
            return NSImage(contentsOf: url)
        case .video:
            return generateThumbnail(for: url)
        }
    }

    var directoryURL: URL { outputDirectory }

    // MARK: - Public API

    @discardableResult
    func save(pngData: Data, effect: Effect) -> PhotoItem {
        let item = persistPhoto(pngData: pngData, effect: effect)
        items.insert(item, at: 0)
        selectedID = item.id
        return item
    }

    /// Copy a finished movie file into our output dir and register it.
    @discardableResult
    func saveVideo(from sourceURL: URL, effect: Effect) -> PhotoItem {
        let name = defaultName(effect: effect, ext: "mov")
        let dest = outputDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        var finalURL: URL? = nil
        do {
            try FileManager.default.moveItem(at: sourceURL, to: dest)
            finalURL = dest
        } catch {
            // Fallback: keep the temp url
            finalURL = sourceURL
        }

        let thumb = Self.generateThumbnail(for: finalURL ?? sourceURL)
        let item = PhotoItem(
            url: finalURL,
            kind: .video,
            effect: effect,
            state: .ready,
            thumbnail: thumb
        )
        items.insert(item, at: 0)
        selectedID = item.id
        return item
    }

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
            let item = items.first(where: { $0.id == id }),
            item.kind == .photo,
            let url = item.url,
            let image = NSImage(contentsOf: url)
        else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    func openExternally(id: UUID) {
        guard let url = items.first(where: { $0.id == id })?.url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    private func persistPhoto(pngData: Data, effect: Effect) -> PhotoItem {
        let url = writeFile(pngData: pngData, effect: effect)
        return PhotoItem(
            url: url,
            kind: .photo,
            effect: effect,
            state: .ready,
            thumbnail: NSImage(data: pngData)
        )
    }

    private func writeFile(pngData: Data, effect: Effect) -> URL? {
        let url = outputDirectory.appendingPathComponent(defaultName(effect: effect, ext: "png"))
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func defaultName(effect: Effect, ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return "photoboothpro-\(formatter.string(from: Date()))-\(effect.fileSuffix).\(ext)"
    }

    private static func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 360, height: 270)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
            return NSImage(cgImage: cg, size: .zero)
        }
        return nil
    }
}
