import SwiftUI
import AppKit

struct PhotoGalleryStrip: View {
    @Bindable var store: PhotoStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.items) { item in
                    thumbnail(for: item)
                        .frame(width: 120, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    store.selectedID == item.id
                                        ? item.effect.accentColor
                                        : .white.opacity(0.08),
                                    lineWidth: store.selectedID == item.id ? 2 : 1
                                )
                        )
                        .onTapGesture { store.selectedID = item.id }
                        .contextMenu {
                            Button("Show in Finder") { store.revealInFinder(id: item.id) }
                                .disabled(item.url == nil)
                            Button("Copy") { store.copyToClipboard(id: item.id) }
                                .disabled(item.url == nil)
                            Divider()
                            Button("Delete", role: .destructive) { store.remove(id: item.id) }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.black.opacity(0.35))
    }

    @ViewBuilder
    private func thumbnail(for item: PhotoItem) -> some View {
        ZStack {
            Color.black
            if let img = item.thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.system(size: 22))
            }

            switch item.state {
            case .processing:
                ZStack {
                    Color.black.opacity(0.35)
                    ShimmerOverlay()
                    VStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text(item.effect.displayName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            case .failed(let msg):
                ZStack {
                    Color.red.opacity(0.35)
                    VStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(msg)
                            .font(.system(size: 8))
                            .lineLimit(2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                    }
                }
            case .ready:
                EmptyView()
            }

            // Effect badge
            if item.effect != .normal, item.state == .ready {
                VStack {
                    HStack {
                        Spacer()
                        Text(item.effect.displayName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(item.effect.accentColor.opacity(0.85)))
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
    }
}
