import SwiftUI

struct ContentView: View {
    let engine: TriageEngine
    @State private var isZoomed = false
    @State private var isPlaying = false
    @State private var showHelp = false
    @State private var viewMode: ViewMode = .triage
    @State private var galleryFilter: GalleryFilter = .all

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
                .ignoresSafeArea()

            if engine.isLoading {
                loadingView
            } else if engine.items.isEmpty {
                emptyView
            } else if viewMode == .gallery {
                galleryContainerView
            } else {
                triageView
            }

            if showHelp {
                helpOverlay
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(KeyboardHandler(
            engine: engine,
            isZoomed: $isZoomed,
            isPlaying: $isPlaying,
            showHelp: $showHelp,
            viewMode: $viewMode,
            galleryFilter: $galleryFilter
        ))
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Text("Scanning files...")
                .font(.title2)
                .foregroundStyle(.white)

            if let progress = engine.scanProgress {
                ProgressView(value: Double(progress.processed), total: Double(max(progress.total, 1)))
                    .progressViewStyle(.linear)
                    .frame(width: 300)
                    .tint(.blue)

                Text("\(progress.processed) / \(progress.total) files")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No photos or videos found")
                .font(.title2)
                .foregroundStyle(.white)
            Text("Supported: JPEG, HEIC, PNG, WebP, RAW, MOV, MP4")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Triage

    private var triageView: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            // Main preview
            PreviewView(
                item: engine.currentItem,
                isZoomed: $isZoomed,
                isPlaying: $isPlaying
            )

            // Filmstrip
            FilmstripView(engine: engine)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Filename and date
            if let item = engine.currentItem {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.filename)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(item.captureDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Star rating display
                if item.starRating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<item.starRating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(.leading, 8)
                }

                // Decision badge
                decisionBadge(for: item)
            }

            Spacer()

            // Progress counter
            progressCounter

            // View mode indicator
            viewModeIndicator
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)))
    }

    private var viewModeIndicator: some View {
        Image(systemName: viewMode == .triage ? "rectangle.split.1x2" : "square.grid.3x3")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .padding(.leading, 12)
            .help(viewMode == .triage ? "Triage view (g for gallery)" : "Gallery view (g for triage)")
    }

    @ViewBuilder
    private func decisionBadge(for item: MediaItem) -> some View {
        switch item.decision {
        case .kept:
            Text("KEPT")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.7))
                .clipShape(.rect(cornerRadius: 4))
        case .rejected:
            Text("REJECTED")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.7))
                .clipShape(.rect(cornerRadius: 4))
        case .undecided:
            EmptyView()
        }
    }

    private var progressCounter: some View {
        let pos = engine.currentIndex + 1
        let total = engine.totalCount
        let kept = engine.keptCount
        let rejected = engine.rejectedCount
        let remaining = engine.remainingCount

        return Text("\(pos) / \(total)  |  \(kept) kept  \(rejected) rejected  \(remaining) remaining")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    // MARK: - Gallery

    private var galleryContainerView: some View {
        VStack(spacing: 0) {
            topBar
            GalleryView(engine: engine, filter: $galleryFilter) { index in
                engine.goTo(index: index)
                viewMode = .triage
            }
        }
    }

    // MARK: - Help Overlay

    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { showHelp = false }

            VStack(alignment: .leading, spacing: 12) {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Group {
                    shortcutRow("h / Left", "Previous photo")
                    shortcutRow("l / Right", "Next photo")
                    shortcutRow("k", "Keep (mark kept, advance)")
                    shortcutRow("j", "Reject (move to _rejected/, advance)")
                    shortcutRow("z", "Undo last action")
                    shortcutRow("1-5", "Star rating (triage) / filter (gallery)")
                    shortcutRow("Space / Enter", "Play/pause video")
                    shortcutRow("f", "Toggle zoom (fit vs full)")
                    shortcutRow("g", "Toggle gallery / triage view")
                    shortcutRow("?", "Show/hide this help")
                }

                Text("Press any key to dismiss")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
            .padding(32)
            .background(Color(white: 0.15))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func shortcutRow(_ key: String, _ description: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(.white)
                .frame(width: 140, alignment: .leading)
            Text(description)
                .foregroundStyle(.secondary)
        }
    }
}
