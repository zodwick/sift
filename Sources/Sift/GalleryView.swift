import SwiftUI

struct GalleryView: View {
    let engine: TriageEngine
    @Binding var filter: GalleryFilter
    let onSelectItem: (Int) -> Void

    private var filteredItems: [(index: Int, item: MediaItem)] {
        engine.items.enumerated().compactMap { index, item in
            switch filter {
            case .all:
                return (index, item)
            case .undecided:
                return item.decision == .undecided ? (index, item) : nil
            case .kept:
                return item.decision == .kept ? (index, item) : nil
            case .rejected:
                return item.decision == .rejected ? (index, item) : nil
            }
        }
    }

    private func filterCount(_ filter: GalleryFilter) -> Int {
        switch filter {
        case .all: return engine.totalCount
        case .undecided: return engine.remainingCount
        case .kept: return engine.keptCount
        case .rejected: return engine.rejectedCount
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            MasonryGrid(
                items: filteredItems,
                currentIndex: engine.currentIndex,
                onSelectItem: onSelectItem
            )
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Array(GalleryFilter.allCases.enumerated()), id: \.offset) { idx, f in
                filterPill(f, shortcut: idx + 1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)))
    }

    private func filterPill(_ f: GalleryFilter, shortcut: Int) -> some View {
        let isActive = filter == f
        let count = filterCount(f)

        return Button {
            filter = f
        } label: {
            Text("\(f.label) (\(count))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.white.opacity(0.15) : Color.clear)
                .clipShape(.capsule)
                .overlay(
                    Capsule().stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Masonry Grid

private struct MasonryGrid: View {
    let items: [(index: Int, item: MediaItem)]
    let currentIndex: Int
    let onSelectItem: (Int) -> Void

    private let targetColumnWidth: CGFloat = 220

    var body: some View {
        GeometryReader { geo in
            let columnCount = max(1, Int(floor(geo.size.width / targetColumnWidth)))
            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(columnCount - 1) + 16 // 8px padding each side
            let columnWidth = (geo.size.width - totalSpacing) / CGFloat(columnCount)
            let columns = assignColumns(items: items, columnCount: columnCount, columnWidth: columnWidth)

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<columnCount, id: \.self) { col in
                            LazyVStack(spacing: spacing) {
                                ForEach(columns[col], id: \.item.id) { entry in
                                    GalleryCellView(
                                        item: entry.item,
                                        isSelected: entry.index == currentIndex,
                                        width: columnWidth,
                                        onTap: { onSelectItem(entry.index) }
                                    )
                                    .id(entry.index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .onChange(of: currentIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }

    /// Shortest-column-first assignment for balanced masonry layout
    private func assignColumns(
        items: [(index: Int, item: MediaItem)],
        columnCount: Int,
        columnWidth: CGFloat
    ) -> [[(index: Int, item: MediaItem)]] {
        var columns: [[(index: Int, item: MediaItem)]] = Array(repeating: [], count: columnCount)
        var heights: [CGFloat] = Array(repeating: 0, count: columnCount)

        for entry in items {
            let shortestCol = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortestCol].append(entry)
            let itemHeight = columnWidth / max(entry.item.aspectRatio, 0.1)
            heights[shortestCol] += itemHeight + 4 // spacing
        }

        return columns
    }
}

// MARK: - Gallery Cell

private struct GalleryCellView: View {
    let item: MediaItem
    let isSelected: Bool
    let width: CGFloat
    let onTap: () -> Void

    @State private var thumbnail: NSImage?

    private var borderColor: Color {
        switch item.decision {
        case .kept: return .green
        case .rejected: return .red
        case .undecided: return .clear
        }
    }

    private var itemHeight: CGFloat {
        width / max(item.aspectRatio, 0.1)
    }

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: itemHeight)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: width, height: itemHeight)
                    .overlay {
                        if item.isVideo {
                            Image(systemName: "film")
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            // Star rating badge
            if item.starRating > 0 {
                VStack {
                    Spacer()
                    HStack(spacing: 1) {
                        ForEach(0..<item.starRating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding(2)
                    .background(.black.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 3))
                    .padding(3)
                }
                .frame(width: width, height: itemHeight, alignment: .bottom)
            }

            // Video badge
            if item.isVideo {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.black.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 3))
                            .padding(3)
                    }
                    Spacer()
                }
                .frame(width: width, height: itemHeight)
            }
        }
        .frame(width: width, height: itemHeight)
        .border(borderColor, width: item.decision != .undecided ? 3 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
        )
        .clipShape(.rect(cornerRadius: 4))
        .shadow(color: isSelected ? .white.opacity(0.4) : .clear, radius: 6)
        .help(item.filename)
        .onTapGesture { onTap() }
        .task(id: item.id) {
            thumbnail = await ThumbnailLoader.shared.galleryThumbnail(for: item)
        }
    }
}
