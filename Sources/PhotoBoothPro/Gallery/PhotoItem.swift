import Foundation
import AppKit

enum PhotoState: Equatable {
    case ready
    case processing
    case failed(String)
}

struct PhotoItem: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var effect: Effect
    var createdAt: Date
    var state: PhotoState
    var thumbnail: NSImage?

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        effect: Effect,
        createdAt: Date = Date(),
        state: PhotoState = .ready,
        thumbnail: NSImage? = nil
    ) {
        self.id = id
        self.url = url
        self.effect = effect
        self.createdAt = createdAt
        self.state = state
        self.thumbnail = thumbnail
    }
}
