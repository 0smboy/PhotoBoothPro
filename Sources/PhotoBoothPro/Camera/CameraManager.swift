import Foundation
import AVFoundation
import AppKit
import Observation

@MainActor
@Observable
final class CameraManager {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.photoboothpro.session")

    /// Strong ref to the delegate used by the current in-flight capture.
    private var activeDelegate: PhotoCaptureDelegate?

    var isConfigured = false
    var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    var errorMessage: String?

    /// When true, preview and captured photos are horizontally flipped (classic
    /// Photo Booth / mirror). When false, WYSIWYG / third-person view.
    var isMirrored: Bool = false

    // MARK: - Lifecycle

    func bootstrap() async {
        authorization = AVCaptureDevice.authorizationStatus(for: .video)

        if authorization == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        }

        guard authorization == .authorized else {
            errorMessage = CameraError.notAuthorized.localizedDescription
            return
        }

        await configure()
        start()
    }

    private func configure() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else { cont.resume(); return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                defer {
                    self.session.commitConfiguration()
                    cont.resume()
                }

                let discovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera, .external],
                    mediaType: .video,
                    position: .unspecified
                )
                guard let device = discovery.devices.first else {
                    Task { @MainActor in self.errorMessage = CameraError.noDevice.localizedDescription }
                    return
                }

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(input) { self.session.addInput(input) }
                } catch {
                    Task { @MainActor in self.errorMessage = error.localizedDescription }
                    return
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                }

                // Force non-mirrored output on every connection.
                for connection in self.photoOutput.connections {
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = false
                    }
                }

                Task { @MainActor in self.isConfigured = true }
            }
        }
    }

    func start() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Capture

    /// Capture a still photo. Returns PNG-encoded data honoring `isMirrored`.
    func capturePhoto() async throws -> Data {
        guard authorization == .authorized, isConfigured else {
            throw CameraError.notAuthorized
        }

        let mirror = isMirrored  // snapshot on main actor

        let rawData: Data = try await withCheckedThrowingContinuation { cont in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality

                let delegate = PhotoCaptureDelegate(continuation: cont)
                Task { @MainActor in self.activeDelegate = delegate }

                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirror
                }

                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
        activeDelegate = nil
        return try Self.convertToPNG(rawData)
    }

    // MARK: - Helpers

    static func convertToPNG(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CameraError.invalidImage
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw CameraError.invalidImage
        }
        return png
    }
}
