import SwiftUI

struct FilmstripView: View {
    let engine: TriageEngine

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 4) {
                    ForEach(Array(engine.items.enumerated()), id: \.element.id) { index, item in
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
