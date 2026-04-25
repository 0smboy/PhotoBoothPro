import Foundation
import AVFoundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Observation

/// Pipes camera frames through a Core Image filter and exposes the latest
/// filtered CIImage to whoever wants to render it (the MTKView preview + the
/// still capture pipeline). Recording uses AVCaptureMovieFileOutput for v1
/// (raw frames, mirror honored via the connection).
@MainActor
@Observable
final class CameraManager: NSObject {
    let session = AVCaptureSession()

    // MARK: Outputs
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let movieOutput = AVCaptureMovieFileOutput()

    private let sessionQueue = DispatchQueue(label: "com.photoboothpro.session")
    private let videoQueue  = DispatchQueue(label: "com.photoboothpro.video")

    /// Strong ref to the delegate that finalizes a recording.
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    // MARK: Published state
    var isConfigured = false
    var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    var errorMessage: String?
    var isRecording: Bool = false

    /// When true, preview and captured photos are horizontally flipped (classic
    /// Photo Booth / mirror). macOS webcam default.
    var isMirrored: Bool = true

    /// Active filter. Setting this updates the preview instantly (next frame).
    var effect: Effect = .normal

    /// Screen-flash behavior for capture.
    var flashMode: FlashMode = .auto

    /// While true, the published preview frames become a solid white image
    /// instead of the camera feed. Driven by ContentView around a capture so
    /// the screen actually emits white light (the "flash"). We do it here —
    /// rather than with a SwiftUI `Color.white` overlay — because MTKView
    /// (AppKit) always draws on top of SwiftUI overlays, so an overlay-based
    /// flash would be invisible on screen and fail to illuminate the subject.
    var isFlashing: Bool = false

    /// Rolling estimate of the scene's perceptual brightness in [0, 1],
    /// computed every ~10 frames with `CIAreaAverage`. Used by the Auto
    /// flash mode since macOS `AVCaptureDevice` doesn't expose ISO/exposure.
    var sceneBrightness: Double = 0.5

    /// Below this average luminance, `.auto` treats the scene as dim and
    /// fires the screen flash. Roughly "obviously indoors at night".
    private let lowLightBrightnessThreshold: Double = 0.30

    private var brightnessSampleCounter = 0

    /// Most recent raw camera frame (no flash white-out, no filter, no mirror).
    /// Used by `capturePhoto()` so that stills come from the EXACT same
    /// pipeline as the live preview and the recorded video — otherwise
    /// `AVCapturePhotoOutput` runs its own scene-/HDR-/skin-tone enhancement
    /// path and produces a slightly redder image than the video stream.
    private var latestRawImage: CIImage?
    /// Native pixel size of the latest frame, used for naming/orientation.
    private var latestRawExtent: CGRect = .zero

    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: true
    ])

    // MARK: Lifecycle

    private var hasMicrophonePermission = false

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

        // Ask for mic permission up front; if denied, video records silent.
        // We MUST NOT add an audio input without permission — macOS aborts.
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch micStatus {
        case .authorized:
            hasMicrophonePermission = true
        case .notDetermined:
            hasMicrophonePermission = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            hasMicrophonePermission = false
        }

        await configure(withAudio: hasMicrophonePermission)
        start()
    }

    private func configure(withAudio includeAudio: Bool) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self, includeAudio] in
                guard let self else { cont.resume(); return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                defer {
                    self.session.commitConfiguration()
                    cont.resume()
                }

                // --- Inputs ---
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
                    let videoInput = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(videoInput) { self.session.addInput(videoInput) }
                } catch {
                    Task { @MainActor in self.errorMessage = error.localizedDescription }
                    return
                }

                // Audio input — ONLY if the user has actively granted
                // microphone permission. Adding an audio device input without
                // it crashes the session (EXC_BAD_INSTRUCTION from caulk).
                if includeAudio,
                   let audioDevice = AVCaptureDevice.default(for: .audio),
                   let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
                   self.session.canAddInput(audioInput) {
                    self.session.addInput(audioInput)
                }

                // --- Outputs ---
                // We DON'T attach AVCapturePhotoOutput. Stills are pulled
                // from the video data output (see `capturePhoto()`) so they
                // share the live preview / recorded video color path
                // exactly. Adding photo output also routes through the
                // ISP's smart-HDR/skin-tone pipeline which produced an
                // unwanted red shift compared to the video stream.
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                if self.session.canAddOutput(self.videoDataOutput) {
                    self.session.addOutput(self.videoDataOutput)
                }

                if self.session.canAddOutput(self.movieOutput) {
                    self.session.addOutput(self.movieOutput)
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

    // MARK: Photo capture

    /// Capture a still photo. Returns PNG bytes with the current filter +
    /// mirror baked in.
    ///
    /// Source: the most recent frame from the video data output — the SAME
    /// pipeline that feeds the live preview and the recorded video. Going
    /// through `AVCapturePhotoOutput` produced visibly different colors
    /// (slight red/saturation push on faces) because that path runs its
    /// own scene/HDR processing on macOS. Using the data-output frame keeps
    /// preview, photo, and video color-identical.
    func capturePhoto() async throws -> Data {
        guard authorization == .authorized, isConfigured else {
            throw CameraError.notAuthorized
        }

        // Wait briefly for a fresh frame if for some reason we don't have
        // one yet (just-launched session, etc.).
        if latestRawImage == nil {
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                if latestRawImage != nil { break }
            }
        }
        guard let raw = latestRawImage else {
            throw CameraError.noPhotoData
        }

        return try Self.encodePhoto(
            raw: raw,
            effect: effect,
            mirror: isMirrored,
            ciContext: ciContext
        )
    }

    /// Apply effect + mirror to a raw camera CIImage and return PNG bytes.
    /// Output is tagged with the source image's color space (or sRGB
    /// fallback) so a viewer interprets it the same as the on-screen preview.
    private static func encodePhoto(
        raw: CIImage,
        effect: Effect,
        mirror: Bool,
        ciContext: CIContext
    ) throws -> Data {
        var ci = effect.apply(to: raw)
        if mirror {
            let flip = CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: -ci.extent.width, y: 0)
            ci = ci.transformed(by: flip)
        }

        let outputCS = raw.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let outCG = ciContext.createCGImage(
            ci,
            from: ci.extent.integral,
            format: .RGBA8,
            colorSpace: outputCS
        ) else {
            throw CameraError.invalidImage
        }
        return try encodeAsPNG(outCG, colorSpace: outputCS)
    }

    private static func encodeAsPNG(_ image: CGImage, colorSpace: CGColorSpace?) throws -> Data {
        let mut = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            mut, "public.png" as CFString, 1, nil
        ) else { throw CameraError.invalidImage }

        var properties: [CFString: Any] = [:]
        if let cs = colorSpace, let cName = cs.name {
            properties[kCGImagePropertyProfileName] = cName as String
        }
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw CameraError.invalidImage
        }
        return mut as Data
    }

    // MARK: Recording

    /// Starts movie recording; returns when the recording actually begins.
    /// Call `stopRecording()` to finalize; the file URL is returned there.
    func startRecording() throws {
        guard !isRecording else { return }
        guard let connection = movieOutput.connection(with: .video) else {
            throw CameraError.invalidImage
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("photoboothpro-\(UUID().uuidString).mov")
        isRecording = true
        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
    }

    /// Stops recording and returns the resulting file URL.
    func stopRecording() async throws -> URL {
        guard isRecording else { throw CameraError.invalidImage }
        return try await withCheckedThrowingContinuation { cont in
            self.recordingContinuation = cont
            self.movieOutput.stopRecording()
        }
    }

    // MARK: Helpers for UI

    /// Whether a screen-flash should fire for the next capture given current mode + scene.
    var shouldFireFlash: Bool {
        switch flashMode {
        case .off:  return false
        case .on:   return true
        case .auto: return sceneBrightness < lowLightBrightnessThreshold
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let source = CIImage(cvPixelBuffer: buffer)

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Cache the raw frame for `capturePhoto()`. Note: this is the
            // unmodified sensor image, even while we're showing white in the
            // preview — the screen flash lights up the subject for real, and
            // we want the lit-and-correctly-exposed sensor frame, not the
            // synthetic white we render to the MTKView.
            self.latestRawImage = source
            self.latestRawExtent = source.extent

            // Rolling scene-brightness sample (~ every 10 frames). Uses
            // `CIAreaAverage` to produce a single RGBA pixel whose value is
            // the average of the whole frame, then converts to luminance.
            self.brightnessSampleCounter &+= 1
            if self.brightnessSampleCounter % 10 == 0 {
                self.updateSceneBrightness(from: source)
            }

            let out: CIImage
            if self.isFlashing {
                out = CIImage(color: CIColor.white).cropped(to: source.extent)
            } else {
                out = source
            }
            FrameBroadcaster.shared.publish(out)
        }
    }

    private func updateSceneBrightness(from image: CIImage) {
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let avg = filter.outputImage else { return }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            avg,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        // Rec. 709 luma.
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        // Lightly smoothed so a single dark frame doesn't flip the mode.
        sceneBrightness = sceneBrightness * 0.6 + luma * 0.4
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isRecording = false
            if let error {
                self.recordingContinuation?.resume(throwing: error)
            } else {
                self.recordingContinuation?.resume(returning: outputFileURL)
            }
            self.recordingContinuation = nil
        }
    }
}
