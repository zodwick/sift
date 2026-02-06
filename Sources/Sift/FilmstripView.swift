import SwiftUI

struct FilmstripView: View {
    let engine: TriageEngine

    private var filter: GalleryFilter { engine.activeFilter }

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

    private func filterCount(_ f: GalleryFilter) -> Int {
        switch f {
        case .all: return engine.totalCount
        case .undecided: return engine.remainingCount
        case .kept: return engine.keptCount
        case .rejected: return engine.rejectedCount
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 4) {
                        ForEach(filteredItems, id: \.item.id) { index, item in
                            ThumbnailCell(
                                item: item,
                                isSelected: index == engine.currentIndex
                            )
                            .id(index)
                            .onTapGesture {
                                engine.goTo(index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .scrollIndicators(.hidden)
                .frame(height: 110)
                .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)))
                .onChange(of: engine.currentIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(engine.currentIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(Array(GalleryFilter.allCases.enumerated()), id: \.offset) { idx, f in
                filterPill(f)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)))
    }

    private func filterPill(_ f: GalleryFilter) -> some View {
        let isActive = filter == f
        let count = filterCount(f)

        return Button {
            engine.activeFilter = f
        } label: {
            Text("\(f.label) (\(count))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(isActive ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isActive ? Color.white.opacity(0.15) : Color.clear)
                .clipShape(.capsule)
                .overlay(
                    Capsule().stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ThumbnailCell: View {
    let item: MediaItem
    let isSelected: Bool

    @State private var thumbnail: NSImage?

    private var borderColor: Color {
        switch item.decision {
        case .kept: return .green
        case .rejected: return .red
        case .undecided: return .clear
        }
    }

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 90, height: 90)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(white: 0.2))
                    .frame(width: 90, height: 90)
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
                .frame(width: 90, height: 90, alignment: .bottom)
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
                .frame(width: 90, height: 90)
            }
        }
        .frame(width: 90, height: 90)
        .border(borderColor, width: item.decision != .undecided ? 3 : 0)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .clipShape(.rect(cornerRadius: 4))
        .shadow(color: isSelected ? .white.opacity(0.3) : .clear, radius: 4)
        .task(id: item.id) {
            thumbnail = await ThumbnailLoader.shared.thumbnail(for: item)
        }
    }
}
