import Foundation

/// What the big center action button does.
enum CaptureMode: String, CaseIterable, Identifiable {
    case photo
    case video

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        }
    }

    var symbol: String {
        switch self {
        case .photo: return "person.crop.square"
        case .video: return "video.fill"
        }
    }
}
