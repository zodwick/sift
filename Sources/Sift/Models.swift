import Foundation
import AppKit
import Observation

// MARK: - Decision

enum Decision: String, Codable {
    case undecided
    case kept
    case rejected
}

// MARK: - MediaItem

@Observable
final class MediaItem: Identifiable {
    let id: String // relative path from root folder
    var url: URL
    let captureDate: Date
    let isVideo: Bool

    var decision: Decision = .undecided
    var starRating: Int = 0 // 0 = unrated, 1-5

    /// Whether this file currently lives in _rejected/
    var isInRejectedFolder: Bool {
        url.deletingLastPathComponent().lastPathComponent == "_rejected"
    }

    /// Original filename
    var filename: String { url.lastPathComponent }

    init(url: URL, captureDate: Date, isVideo: Bool, id: String) {
        self.url = url
        self.captureDate = captureDate
        self.isVideo = isVideo
        self.id = id
    }
}

// MARK: - UndoAction

struct UndoAction {
    enum Kind {
        case reject(originalURL: URL, rejectedURL: URL)
        case keep
        case rate(previousRating: Int)
    }

    let itemID: String
    let kind: Kind
    let previousDecision: Decision
}

// MARK: - Session Data (Codable for JSON persistence)

struct SessionData: Codable {
    var fileStates: [String: FileState] = [:]
    var currentPosition: Int = 0

    struct FileState: Codable {
        var decision: String // "undecided", "kept", "rejected"
        var starRating: Int
    }
}

// MARK: - Supported formats

enum SupportedFormats {
    static let photoExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "webp",
        "cr2", "arw", "nef", "dng"
    ]

    static let videoExtensions: Set<String> = [
        "mov", "mp4"
    ]

    static let allExtensions: Set<String> = photoExtensions.union(videoExtensions)

    static func isSupported(_ url: URL) -> Bool {
        allExtensions.contains(url.pathExtension.lowercased())
    }

    static func isVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }
}
