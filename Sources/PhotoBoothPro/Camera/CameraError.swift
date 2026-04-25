import Foundation

enum CameraError: LocalizedError {
    case notAuthorized
    case noDevice
    case noPhotoData
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access was denied. Enable it in System Settings › Privacy & Security › Camera."
        case .noDevice:
            return "No camera was found."
        case .noPhotoData:
            return "Failed to capture photo data — no fresh frame available yet."
        case .invalidImage:
            return "Captured image could not be encoded."
        }
    }
}
