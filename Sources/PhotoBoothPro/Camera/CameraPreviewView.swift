import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI wrapper around AVCaptureVideoPreviewLayer. Honors `isMirrored` for
/// live preview mirroring, independent of the photo output.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool = false

    func makeNSView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.attach(session: session)
        view.setMirrored(isMirrored)
        return view
    }

    func updateNSView(_ nsView: PreviewContainerView, context: Context) {
        nsView.attach(session: session)
        nsView.setMirrored(isMirrored)
    }
}

final class PreviewContainerView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }

    func attach(session: AVCaptureSession) {
        guard previewLayer == nil else { return }
        wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer?.addSublayer(layer)
        self.previewLayer = layer
    }

    func setMirrored(_ mirrored: Bool) {
        guard let connection = previewLayer?.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirrored != mirrored {
            connection.isVideoMirrored = mirrored
        }
    }
}
