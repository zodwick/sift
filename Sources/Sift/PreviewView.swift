import SwiftUI
import AVKit

struct PreviewView: View {
    let item: MediaItem?
    @Binding var isZoomed: Bool
    @Binding var isPlaying: Bool

    @State private var previewImage: NSImage?
    @State private var fullImage: NSImage?
    @State private var magnification: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))

                if let item = item {
                    if item.isVideo {
                        videoPreview(item: item, size: geo.size)
                    } else {
                        imagePreview(size: geo.size)
                    }
                } else {
                    Text("No media selected")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
            }
        }
        .task(id: item?.id) {
            // Runs synchronously up to the first await, then cancels automatically on item change
            previewImage = nil
            fullImage = nil
            isZoomed = false
            magnification = 1.0
            offset = .zero

            guard let item = item else { return }

            let image = await ThumbnailLoader.shared.preview(for: item)
            if !Task.isCancelled {
                previewImage = image
            }
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    magnification = value.magnification
                }
                .onEnded { value in
                    if value.magnification > 1.5 {
                        isZoomed = true
                        loadFullRes()
                    } else {
                        isZoomed = false
                        magnification = 1.0
                        offset = .zero
                    }
                }
        )
    }

    @ViewBuilder
    private func imagePreview(size: CGSize) -> some View {
        let displayImage = isZoomed ? (fullImage ?? previewImage) : previewImage

        if let image = displayImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: isZoomed ? .fill : .fit)
                .scaleEffect(isZoomed ? max(magnification, 1.0) : 1.0)
                .offset(offset)
                .frame(width: size.width, height: size.height)
                .clipped()
                .gesture(
                    isZoomed ?
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation
                        }
                    : nil
                )
        } else if item != nil {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Unable to load image")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func videoPreview(item: MediaItem, size: CGSize) -> some View {
        if isPlaying {
            VideoPlayerView(url: item.url, isPlaying: $isPlaying)
                .frame(width: size.width, height: size.height)
        } else {
            // Show first frame as still
            if let image = previewImage {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 4)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Video")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func loadFullRes() {
        guard let item = item, !item.isVideo else { return }
        Task {
            let image = await ThumbnailLoader.shared.fullResolution(for: item)
            if !Task.isCancelled, self.item?.id == item.id {
                self.fullImage = image
            }
        }
    }
}

// MARK: - Video Player

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        let player = AVPlayer(url: url)
        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = false
        player.play()
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if !isPlaying {
            nsView.player?.pause()
        }
    }
}
