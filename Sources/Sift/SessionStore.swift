import Foundation

@MainActor
final class SessionStore {
    private let sessionURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var data: SessionData
    private var saveTask: Task<Void, Never>?

    init(rootURL: URL) {
        self.sessionURL = rootURL.appendingPathComponent(".sift_session.json")
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let jsonData = try? Data(contentsOf: sessionURL),
           let loaded = try? decoder.decode(SessionData.self, from: jsonData) {
            self.data = loaded
        } else {
            self.data = SessionData()
        }
    }

    var currentPosition: Int {
        get { data.currentPosition }
        set {
            data.currentPosition = newValue
            scheduleSave()
        }
    }

    /// Apply stored session state to scanned items
    func applyToItems(_ items: [MediaItem]) {
        for item in items {
            if let state = data.fileStates[item.id] {
                item.decision = Decision(rawValue: state.decision) ?? .undecided
                item.starRating = state.starRating
            }
        }
    }

    /// Update a single item's state in the session
    func updateItem(_ item: MediaItem) {
        data.fileStates[item.id] = SessionData.FileState(
            decision: item.decision.rawValue,
            starRating: item.starRating
        )
        scheduleSave()
    }

    /// Debounced save — coalesces rapid updates (e.g., fast h/l navigation)
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        do {
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: sessionURL, options: .atomic)
        } catch {
            print("Warning: Failed to save session: \(error.localizedDescription)")
        }
    }
}
