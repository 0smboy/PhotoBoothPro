import SwiftUI
import AppKit
import AVKit

/// Full-window viewer for a single captured item. Photos render via
/// `Image(nsImage:)`, videos via AVKit's `VideoPlayer`. Left/right arrow
/// keys flip through the whole gallery; `Esc` dismisses.
struct MediaViewerView: View {
    @Bindable var store: PhotoStore
    @Binding var currentID: UUID?
    let onClose: () -> Void

    @State private var player: AVPlayer?
    @State private var playerItemID: UUID?

    private var index: Int? {
        guard let currentID else { return nil }
        return store.items.firstIndex(where: { $0.id == currentID })
    }

    private var currentItem: PhotoItem? {
        guard let i = index else { return nil }
        return store.items[i]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
                .onTapGesture { onClose() }

            if let item = currentItem {
                VStack(spacing: 14) {
                    header(for: item)
                    content(for: item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    toolbar(for: item)
                }
                .padding(24)

                navigationButtons
            } else {
                Text("Nothing to show")
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: currentID) { _, _ in swapPlayerIfNeeded() }
        .onAppear { swapPlayerIfNeeded() }
        .onDisappear {
            player?.pause()
            player = nil
            playerItemID = nil
        }
        .background(KeyboardCapture(onPrev: prev, onNext: next, onClose: onClose))
    }

    // MARK: - Pieces

    private func header(for item: PhotoItem) -> some View {
        HStack(spacing: 10) {
            Label {
                Text(item.effect.displayName)
                    .font(.system(size: 13, weight: .semibold))
            } icon: {
                Image(systemName: item.kind == .video ? "video.fill" : "photo.fill")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(item.effect.accentColor.opacity(0.85)))
            .foregroundStyle(.white)

            Text(item.createdAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            if let i = index {
                Text("\(i + 1) / \(store.items.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white, .white.opacity(0.15))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close (Esc)")
        }
    }

    @ViewBuilder
    private func content(for item: PhotoItem) -> some View {
        ZStack {
            switch item.kind {
            case .photo:
                if let url = item.url,
                   let ns = NSImage(contentsOf: url) {
                    Image(nsImage: ns)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                } else {
                    brokenPlaceholder
                }
            case .video:
                if let player {
                    AVPlayerHostView(player: player)
                        .onAppear { player.play() }
                } else if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.9), .black.opacity(0.4))
                        }
                } else {
                    brokenPlaceholder
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var brokenPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.yellow)
            Text("File not found")
                .foregroundStyle(.secondary)
        }
    }

    private func toolbar(for item: PhotoItem) -> some View {
        HStack(spacing: 10) {
            Button {
                store.revealInFinder(id: item.id)
            } label: { Label("Show in Finder", systemImage: "folder") }
            .disabled(item.url == nil)

            if item.kind == .photo {
                Button {
                    store.copyToClipboard(id: item.id)
                } label: { Label("Copy", systemImage: "doc.on.doc") }
                .disabled(item.url == nil)
            } else {
                Button {
                    store.openExternally(id: item.id)
                } label: { Label("Open externally", systemImage: "arrow.up.right.square") }
                .disabled(item.url == nil)
            }

            Spacer()

            Button(role: .destructive) {
                let wasID = item.id
                let nextID = neighborID(after: wasID)
                store.remove(id: wasID)
                currentID = nextID
                if nextID == nil { onClose() }
            } label: { Label("Delete", systemImage: "trash") }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private var navigationButtons: some View {
        HStack {
            arrow(systemName: "chevron.left", action: prev)
                .disabled(!canGoPrev)
            Spacer()
            arrow(systemName: "chevron.right", action: next)
                .disabled(!canGoNext)
        }
        .padding(.horizontal, 14)
    }

    private func arrow(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation

    private var canGoPrev: Bool { (index ?? 0) > 0 }
    private var canGoNext: Bool { (index ?? Int.max) < store.items.count - 1 }

    private func prev() {
        guard let i = index, i > 0 else { return }
        currentID = store.items[i - 1].id
        store.selectedID = currentID
    }

    private func next() {
        guard let i = index, i < store.items.count - 1 else { return }
        currentID = store.items[i + 1].id
        store.selectedID = currentID
    }

    private func neighborID(after id: UUID) -> UUID? {
        guard let i = store.items.firstIndex(where: { $0.id == id }) else { return nil }
        if i + 1 < store.items.count { return store.items[i + 1].id }
        if i > 0 { return store.items[i - 1].id }
        return nil
    }

    // MARK: - Player handling

    private func swapPlayerIfNeeded() {
        guard let item = currentItem else {
            player?.pause(); player = nil; playerItemID = nil
            return
        }
        if item.kind == .photo {
            player?.pause(); player = nil; playerItemID = nil
            return
        }
        if playerItemID == item.id, player != nil { return }

        player?.pause()
        if let url = item.url {
            let p = AVPlayer(url: url)
            p.actionAtItemEnd = .pause
            player = p
            playerItemID = item.id
        } else {
            player = nil
            playerItemID = nil
        }
    }
}

// MARK: - AVPlayerView host
//
// We deliberately don't use SwiftUI's `VideoPlayer(player:)` here. On
// macOS 14/15 launching it from inside a `NSViewRepresentable`-heavy
// hierarchy crashes during AVKit's Swift class-metadata bring-up
// (`_AVKit_SwiftUI` → `getSuperclassMetadata` → `swift::fatalError` → abort).
// AVKit's native `AVPlayerView` works reliably and gives us the full
// macOS controls UI for free.

private struct AVPlayerHostView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = player
        v.controlsStyle = .floating
        v.showsFullScreenToggleButton = false
        v.videoGravity = .resizeAspect
        return v
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player { nsView.player = player }
    }
}

// MARK: - Invisible keyboard shortcut host

/// Wires up ←, →, Esc, and Space (play/pause) to the viewer's actions.
private struct KeyboardCapture: View {
    let onPrev: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Button(action: onPrev) { EmptyView() }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .hidden()
            Button(action: onNext) { EmptyView() }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .hidden()
            Button(action: onClose) { EmptyView() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
        .frame(width: 0, height: 0)
    }
}
