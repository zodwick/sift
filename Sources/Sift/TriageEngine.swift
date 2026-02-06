import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
final class TriageEngine {
    var items: [MediaItem] = []
    var currentIndex: Int = 0
    var isLoading = true
    var scanProgress: MediaScanner.ScanProgress?
    var activeFilter: GalleryFilter = .all

    // Cached counts — maintained incrementally instead of filtering 3600 items per render
    private(set) var keptCount: Int = 0
    private(set) var rejectedCount: Int = 0
    var remainingCount: Int { items.count - keptCount - rejectedCount }
    var totalCount: Int { items.count }

    private var undoStack: [UndoAction] = []
    private let maxUndoDepth = 50

    let rootURL: URL
    private let rejectedURL: URL
    private var sessionStore: SessionStore
    private let fm = FileManager.default

    // O(1) lookup by item ID
    private var indexByID: [String: Int] = [:]

    var currentItem: MediaItem? {
        guard !items.isEmpty, currentIndex >= 0, currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.rejectedURL = rootURL.appendingPathComponent("_rejected")
        self.sessionStore = SessionStore(rootURL: rootURL)
    }

    func startScan() async {
        isLoading = true
        let scanner = MediaScanner(rootURL: rootURL)

        let scanned = await scanner.scan { [weak self] progress in
            Task { @MainActor in
                self?.scanProgress = progress
            }
        }

        items = scanned
        rebuildIndex()
        sessionStore.applyToItems(items)
        recomputeCounts()
        currentIndex = min(sessionStore.currentPosition, max(items.count - 1, 0))
        isLoading = false

        prefetchAdjacent()
    }

    // MARK: - Navigation

    func goToNext() {
        if activeFilter == .all {
            guard currentIndex < items.count - 1 else { return }
            currentIndex += 1
        } else {
            guard let next = nextMatchingIndex(after: currentIndex) else { return }
            currentIndex = next
        }
        sessionStore.currentPosition = currentIndex
        prefetchAdjacent()
    }

    func goToPrevious() {
        if activeFilter == .all {
            guard currentIndex > 0 else { return }
            currentIndex -= 1
        } else {
            guard let prev = previousMatchingIndex(before: currentIndex) else { return }
            currentIndex = prev
        }
        sessionStore.currentPosition = currentIndex
        prefetchAdjacent()
    }

    private func matchesFilter(_ item: MediaItem) -> Bool {
        switch activeFilter {
        case .all: return true
        case .undecided: return item.decision == .undecided
        case .kept: return item.decision == .kept
        case .rejected: return item.decision == .rejected
        }
    }

    private func nextMatchingIndex(after index: Int) -> Int? {
        for i in (index + 1)..<items.count {
            if matchesFilter(items[i]) { return i }
        }
        return nil
    }

    private func previousMatchingIndex(before index: Int) -> Int? {
        for i in stride(from: index - 1, through: 0, by: -1) {
            if matchesFilter(items[i]) { return i }
        }
        return nil
    }

    func goTo(index: Int) {
        guard index >= 0, index < items.count else { return }
        currentIndex = index
        sessionStore.currentPosition = currentIndex
        prefetchAdjacent()
    }

    // MARK: - Triage Actions

    func keepCurrent() {
        guard let item = currentItem else { return }

        pushUndo(UndoAction(
            itemID: item.id,
            kind: .keep,
            previousDecision: item.decision
        ))

        // If it was previously rejected, move it back
        if item.decision == .rejected && item.isInRejectedFolder {
            moveFromRejected(item)
        }

        updateCounts(from: item.decision, to: .kept)
        item.decision = .kept
        sessionStore.updateItem(item)
        goToNext()
    }

    func rejectCurrent() {
        guard let item = currentItem else { return }
        let originalURL = item.url

        pushUndo(UndoAction(
            itemID: item.id,
            kind: .reject(originalURL: originalURL, rejectedURL: rejectedDestination(for: item)),
            previousDecision: item.decision
        ))

        // Move file to _rejected/
        moveToRejected(item)

        updateCounts(from: item.decision, to: .rejected)
        item.decision = .rejected
        sessionStore.updateItem(item)
        goToNext()
    }

    func setRating(_ rating: Int) {
        guard let item = currentItem, item.decision == .kept else { return }
        let clamped = max(0, min(5, rating))

        pushUndo(UndoAction(
            itemID: item.id,
            kind: .rate(previousRating: item.starRating),
            previousDecision: item.decision
        ))

        item.starRating = clamped
        sessionStore.updateItem(item)
    }

    // MARK: - Undo

    func undo() {
        guard let action = undoStack.popLast() else { return }
        guard let item = itemByID(action.itemID) else { return }

        switch action.kind {
        case .reject(let originalURL, _):
            if item.isInRejectedFolder {
                moveBack(item, to: originalURL)
            }

        case .keep:
            break

        case .rate(let previousRating):
            item.starRating = previousRating
        }

        updateCounts(from: item.decision, to: action.previousDecision)
        item.decision = action.previousDecision
        sessionStore.updateItem(item)

        // Jump back to that photo
        if let idx = indexByID[action.itemID] {
            currentIndex = idx
            sessionStore.currentPosition = currentIndex
        }
    }

    // MARK: - Index & Counts

    private func rebuildIndex() {
        indexByID.removeAll(keepingCapacity: true)
        indexByID.reserveCapacity(items.count)
        for (i, item) in items.enumerated() {
            indexByID[item.id] = i
        }
    }

    private func recomputeCounts() {
        keptCount = 0
        rejectedCount = 0
        for item in items {
            switch item.decision {
            case .kept: keptCount += 1
            case .rejected: rejectedCount += 1
            case .undecided: break
            }
        }
    }

    private func updateCounts(from old: Decision, to new: Decision) {
        if old == new { return }
        switch old {
        case .kept: keptCount -= 1
        case .rejected: rejectedCount -= 1
        case .undecided: break
        }
        switch new {
        case .kept: keptCount += 1
        case .rejected: rejectedCount += 1
        case .undecided: break
        }
    }

    private func itemByID(_ id: String) -> MediaItem? {
        guard let idx = indexByID[id], idx < items.count else { return nil }
        return items[idx]
    }

    // MARK: - Prefetch

    private func prefetchAdjacent() {
        let indices = [currentIndex - 1, currentIndex + 1, currentIndex + 2]
        for idx in indices where idx >= 0 && idx < items.count {
            let item = items[idx]
            Task.detached(priority: .utility) {
                _ = await ThumbnailLoader.shared.preview(for: item)
            }
        }
    }

    // MARK: - File Operations

    private func rejectedDestination(for item: MediaItem) -> URL {
        return rejectedURL.appendingPathComponent(item.filename)
    }

    private func moveToRejected(_ item: MediaItem) {
        do {
            if !fm.fileExists(atPath: rejectedURL.path) {
                try fm.createDirectory(at: rejectedURL, withIntermediateDirectories: true)
            }

            let dest = rejectedDestination(for: item)
            try fm.moveItem(at: item.url, to: dest)
            item.url = dest
        } catch {
            print("Error moving to rejected: \(error.localizedDescription)")
        }
    }

    private func moveFromRejected(_ item: MediaItem) {
        let originalName = item.filename
        let dest = rootURL.appendingPathComponent(originalName)
        do {
            try fm.moveItem(at: item.url, to: dest)
            item.url = dest
        } catch {
            print("Error moving from rejected: \(error.localizedDescription)")
        }
    }

    private func moveBack(_ item: MediaItem, to originalURL: URL) {
        do {
            try fm.moveItem(at: item.url, to: originalURL)
            item.url = originalURL
        } catch {
            print("Error moving back: \(error.localizedDescription)")
        }
    }

    private func pushUndo(_ action: UndoAction) {
        undoStack.append(action)
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst()
        }
    }
}
