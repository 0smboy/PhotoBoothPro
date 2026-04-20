import Foundation
import AVFoundation

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let continuation: CheckedContinuation<Data, Error>
    private var didResume = false

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard !didResume else { return }
        didResume = true

        if let error = error {
            continuation.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            continuation.resume(throwing: CameraError.noPhotoData)
            return
        }
        continuation.resume(returning: data)
    }
}

enum CameraError: LocalizedError {
    case notAuthorized
    case noDevice
    case noPhotoData
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Camera access was denied. Enable it in System Settings › Privacy & Security › Camera."
        case .noDevice:      return "No camera was found."
        case .noPhotoData:   return "Failed to capture photo data."
        case .invalidImage:  return "Captured image could not be decoded."
        }
    }
}
