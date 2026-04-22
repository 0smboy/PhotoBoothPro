import SwiftUI
import AppKit

struct ContentView: View {
    @State private var camera = CameraManager()
    @State private var store = PhotoStore()
    @State private var effect: Effect = .normal
    @State private var showingEffects = false
    @State private var showingOnboarding = false
    @State private var busy = false
    @State private var toast: Toast?
    @State private var dismissTask: Task<Void, Never>?
    @State private var isFlashing = false

    @State private var recordingStart: Date?
    @State private var recordingTick: TimeInterval = 0
    @State private var recordingTimer: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                previewArea
                gallerySection
                bottomBar
            }

            if showingEffects {
                EffectsGridView(
                    selection: Binding(
                        get: { effect },
                        set: { newValue in
                            effect = newValue
                            camera.effect = newValue
                        }
                    ),
                    camera: camera
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingEffects = false
                    }
                }
                .zIndex(10)
            }

            if let toast {
                VStack {
                    ToastView(toast: toast)
                        .padding(.top, 14)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }

            FlashOverlay(isActive: isFlashing)
                .zIndex(30)
        }
        .frame(minWidth: 860, minHeight: 620)
        .task { await camera.bootstrap() }
        .onDisappear {
            camera.stop()
            recordingTimer?.cancel()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView { key in
                APIKeyStore.save(key)
                present(.init(message: "API key saved", kind: .success))
            }
        }
        .onExitCommand {
            if showingEffects {
                withAnimation { showingEffects = false }
            }
        }
        .background(KeyShortcuts(
            takePhoto: { takePhoto() },
            toggleEffects: { toggleEffects() },
            toggleRecording: { toggleRecording() }
        ))
    }

    // MARK: - Subviews

    private var previewArea: some View {
        ZStack {
            if camera.authorization == .authorized {
                CameraPreviewView(camera: camera)
                    .overlay(alignment: .topTrailing) {
                        if !isIdentity(effect) {
                            Label(effect.displayName, systemImage: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(effect.accentColor.opacity(0.9)))
                                .foregroundStyle(.white)
                                .padding(14)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if camera.isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                Text("REC \(Self.timeString(recordingTick))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.6)))
                            .padding(14)
                        }
                    }
                    .overlay {
                        if busy { ShimmerOverlay() }
                    }
            } else {
                cameraPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(camera.errorMessage ?? "Camera not ready")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if camera.authorization == .denied {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .padding(40)
    }

    private var gallerySection: some View {
        Group {
            if !store.items.isEmpty {
                PhotoGalleryStrip(store: store)
                    .frame(height: 108)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            MirrorModeToggle(isMirrored: Binding(
                get: { camera.isMirrored },
                set: { camera.isMirrored = $0 }
            ))

            FlashModeButton(mode: Binding(
                get: { camera.flashMode },
                set: { camera.flashMode = $0 }
            ))

            Spacer()

            RecordButton(
                isRecording: camera.isRecording,
                isDisabled: busy || camera.authorization != .authorized,
                duration: camera.isRecording ? recordingTick : nil
            ) {
                toggleRecording()
            }

            ShutterButton(isBusy: busy) {
                takePhoto()
            }

            Spacer()

            Button {
                toggleEffects()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Effects")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(showingEffects
                              ? Color.accentColor.opacity(0.35)
                              : Color.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08)))
                )
            }
            .buttonStyle(.plain)
            .help("Toggle Effects (E)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.6))
    }

    // MARK: - Actions

    private func toggleEffects() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showingEffects.toggle()
        }
    }

    private func takePhoto() {
        guard !busy, camera.authorization == .authorized else { return }
        if effect.isAI, !ImageEditService.isAvailable() {
            showingOnboarding = true
            return
        }
        if camera.isRecording { return }

        busy = true
        Task {
            defer { Task { @MainActor in busy = false } }
            let fireFlash = camera.shouldFireFlash
            if fireFlash {
                withAnimation(.easeOut(duration: 0.06)) { isFlashing = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            do {
                let pngData = try await camera.capturePhoto()
                if fireFlash {
                    withAnimation(.easeIn(duration: 0.22)) { isFlashing = false }
                }

                if !effect.isAI {
                    store.save(pngData: pngData, effect: effect)
                    present(.init(
                        message: "Saved to \(store.directoryURL.lastPathComponent)",
                        kind: .success
                    ))
                } else {
                    guard let prompt = effect.prompt else { return }
                    let placeholderID = store.insertProcessing(
                        effect: effect,
                        originalThumbnail: NSImage(data: pngData)
                    )
                    Task.detached {
                        do {
                            let styled = try await ImageEditService.edit(imageData: pngData, prompt: prompt)
                            await MainActor.run {
                                store.complete(id: placeholderID, pngData: styled)
                                present(.init(
                                    message: "\(effect.displayName) ready",
                                    kind: .success
                                ))
                            }
                        } catch {
                            await MainActor.run {
                                store.fail(id: placeholderID, message: error.localizedDescription)
                                present(.init(message: error.localizedDescription, kind: .error))
                            }
                        }
                    }
                }
            } catch {
                if fireFlash {
                    withAnimation(.easeIn(duration: 0.22)) { isFlashing = false }
                }
                present(.init(message: error.localizedDescription, kind: .error))
            }
        }
    }

    private func toggleRecording() {
        guard camera.authorization == .authorized else { return }
        if camera.isRecording {
            recordingTimer?.cancel(); recordingTimer = nil
            Task {
                do {
                    let url = try await camera.stopRecording()
                    store.saveVideo(from: url, effect: effect)
                    present(.init(message: "Video saved", kind: .success))
                } catch {
                    present(.init(message: error.localizedDescription, kind: .error))
                }
            }
        } else {
            do {
                try camera.startRecording()
                recordingStart = Date()
                recordingTick = 0
                recordingTimer = Task { @MainActor in
                    while !Task.isCancelled, camera.isRecording {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        if let start = recordingStart {
                            recordingTick = Date().timeIntervalSince(start)
                        }
                    }
                }
            } catch {
                present(.init(message: error.localizedDescription, kind: .error))
            }
        }
    }

    private func present(_ t: Toast) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { toast = t }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) { toast = nil }
            }
        }
    }

    private func isIdentity(_ e: Effect) -> Bool {
        if case .local(.none) = e { return true }
        return false
    }

    private static func timeString(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct KeyShortcuts: View {
    let takePhoto: () -> Void
    let toggleEffects: () -> Void
    let toggleRecording: () -> Void

    var body: some View {
        ZStack {
            Button(action: takePhoto) { EmptyView() }
                .keyboardShortcut(.space, modifiers: [])
                .hidden()
            Button(action: toggleEffects) { EmptyView() }
                .keyboardShortcut("e", modifiers: [])
                .hidden()
            Button(action: toggleRecording) { EmptyView() }
                .keyboardShortcut("r", modifiers: [.command])
                .hidden()
        }
        .frame(width: 0, height: 0)
    }
}
