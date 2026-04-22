import Foundation
import CoreImage

/// Thread-safe fan-out for camera frames.
///
/// `CameraManager` publishes one raw CIImage per delivered sample buffer;
/// every subscriber (the main preview and each per-tile filter preview)
/// receives the same source image and applies its own filter/mirror.
///
/// This avoids the "only one callback at a time" limitation of the original
/// pipeline and lets the Effects grid render live filtered thumbnails
/// without fighting the main preview.
@MainActor
final class FrameBroadcaster {
    static let shared = FrameBroadcaster()
    private init() {}

    typealias Subscriber = (CIImage) -> Void
    private var subscribers: [UUID: Subscriber] = [:]

    @discardableResult
    func subscribe(_ block: @escaping Subscriber) -> UUID {
        let id = UUID()
        subscribers[id] = block
        return id
    }

    func unsubscribe(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    func publish(_ image: CIImage) {
        for sub in subscribers.values { sub(image) }
    }
}
