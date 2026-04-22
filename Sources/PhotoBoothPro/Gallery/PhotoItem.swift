import Foundation
import AppKit

enum PhotoState: Equatable {
    case ready
    case processing
    case failed(String)
}

enum MediaKind: String { case photo, video }

struct PhotoItem: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var kind: MediaKind
    var effect: Effect
    var createdAt: Date
    var state: PhotoState
    var thumbnail: NSImage?

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        kind: MediaKind = .photo,
        effect: Effect,
        createdAt: Date = Date(),
        state: PhotoState = .ready,
        thumbnail: NSImage? = nil
    ) {
        self.id = id
        self.url = url
        self.kind = kind
        self.effect = effect
        self.createdAt = createdAt
        self.state = state
        self.thumbnail = thumbnail
    }
}
