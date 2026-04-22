import SwiftUI
import AppKit
import Metal
import MetalKit
import CoreImage
import AVFoundation

/// Live preview for the main viewport. Subscribes to the `FrameBroadcaster`
/// and applies whatever effect + mirror state the camera currently has.
struct CameraPreviewView: NSViewRepresentable {
    let camera: CameraManager
    var aspectFillMode: AspectMode = .fill

    enum AspectMode { case fill, fit }

    func makeNSView(context: Context) -> FilteredMetalPreview {
        let v = FilteredMetalPreview()
        v.aspectMode = aspectFillMode
        v.configure(camera: camera, resolver: .mainPreview)
        return v
    }

    func updateNSView(_ nsView: FilteredMetalPreview, context: Context) {
        nsView.aspectMode = aspectFillMode
        nsView.configure(camera: camera, resolver: .mainPreview)
    }
}

/// What filter to apply when a tile/preview sees a raw frame.
enum FrameFilterResolver {
    case mainPreview                  // uses camera.effect + camera.isMirrored
    case specific(LocalFilter)        // uses this filter + camera.isMirrored
}

/// Metal-backed NSView rendering the most recent filtered CIImage.
final class FilteredMetalPreview: NSView {
    var aspectMode: CameraPreviewView.AspectMode = .fill

    private var metalView: MTKView?
    private var renderer: MetalCIRenderer?
    private var subscription: UUID?
    private weak var camera: CameraManager?

    override init(frame frameRect: NSRect) { super.init(frame: frameRect); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    deinit {
        if let subscription {
            let id = subscription
            Task { @MainActor in FrameBroadcaster.shared.unsubscribe(id) }
        }
    }

    override func layout() {
        super.layout()
        metalView?.frame = bounds
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let mv = MTKView(frame: bounds, device: device)
        mv.framebufferOnly = false
        mv.autoresizingMask = [.width, .height]
        mv.enableSetNeedsDisplay = false
        mv.isPaused = false
        mv.preferredFramesPerSecond = 30
        mv.colorPixelFormat = .bgra8Unorm
        mv.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        addSubview(mv)
        metalView = mv

        let r = MetalCIRenderer(device: device, view: mv, aspectProvider: { [weak self] in
            self?.aspectMode ?? .fill
        })
        mv.delegate = r
        renderer = r
    }

    @MainActor
    func configure(camera: CameraManager, resolver: FrameFilterResolver) {
        self.camera = camera
        if subscription != nil { return }     // one subscription per view

        let renderer = renderer
        subscription = FrameBroadcaster.shared.subscribe { [weak camera] source in
            guard let camera, let renderer else { return }

            var ci: CIImage
            switch resolver {
            case .mainPreview:
                ci = camera.effect.apply(to: source)
            case .specific(let f):
                ci = f.apply(to: source)
            }
            if camera.isMirrored {
                let flip = CGAffineTransform(scaleX: -1, y: 1)
                    .translatedBy(x: -ci.extent.width, y: 0)
                ci = ci.transformed(by: flip)
            }
            renderer.setImage(ci)
        }
    }
}

// MARK: - Core Image → Metal renderer

final class MetalCIRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let ciContext: CIContext
    private weak var mtkView: MTKView?
    private let aspectProvider: () -> CameraPreviewView.AspectMode

    private let imageLock = NSLock()
    private var currentImage: CIImage?

    init(device: MTLDevice, view: MTKView, aspectProvider: @escaping () -> CameraPreviewView.AspectMode) {
        self.device = device
        self.queue = device.makeCommandQueue()!
        self.ciContext = CIContext(mtlDevice: device, options: [.cacheIntermediates: true])
        self.mtkView = view
        self.aspectProvider = aspectProvider
        super.init()
    }

    func setImage(_ image: CIImage) {
        imageLock.lock()
        currentImage = image
        imageLock.unlock()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        imageLock.lock()
        let image = currentImage
        imageLock.unlock()
        guard
            let image,
            let drawable = view.currentDrawable,
            let commandBuffer = queue.makeCommandBuffer()
        else { return }

        let drawableSize = view.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else { return }

        let scaled = scale(image: image, into: drawableSize, mode: aspectProvider())

        let destRect = CGRect(origin: .zero, size: drawableSize)
        ciContext.render(
            scaled,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: destRect,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func scale(image: CIImage, into size: CGSize, mode: CameraPreviewView.AspectMode) -> CIImage {
        let src = image.extent
        guard src.width > 0, src.height > 0 else { return image }
        let sx = size.width / src.width
        let sy = size.height / src.height
        let s: CGFloat
        switch mode {
        case .fill: s = max(sx, sy)
        case .fit:  s = min(sx, sy)
        }
        let scaled = image.transformed(by: .init(scaleX: s, y: s))
        let e = scaled.extent
        let tx = (size.width  - e.width)  / 2 - e.origin.x
        let ty = (size.height - e.height) / 2 - e.origin.y
        return scaled.transformed(by: .init(translationX: tx, y: ty))
    }
}
