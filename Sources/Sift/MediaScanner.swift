import Foundation
import ImageIO
import AVFoundation

final class MediaScanner {
    let rootURL: URL
    private let rejectedURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.rejectedURL = rootURL.appendingPathComponent("_rejected")
    }

    struct ScanProgress {
        var found: Int
        var processed: Int
        var total: Int
    }

    /// Scan root folder and _rejected/ for media files, sorted by capture date
    func scan(progress: @escaping (ScanProgress) -> Void) async -> [MediaItem] {
        let fileURLs = collectFiles()
        let total = fileURLs.count

        progress(ScanProgress(found: total, processed: 0, total: total))

        var items: [MediaItem] = []
        var processed = 0

        await withTaskGroup(of: MediaItem?.self) { group in
            for url in fileURLs {
                group.addTask {
                    await self.processFile(url: url)
                }
            }

            for await item in group {
                processed += 1
                if processed % 50 == 0 {
                    progress(ScanProgress(found: total, processed: processed, total: total))
                }
                if let item = item {
                    items.append(item)
                }
            }
        }

        progress(ScanProgress(found: total, processed: total, total: total))

        // Sort by capture date
        items.sort { $0.captureDate < $1.captureDate }
        return items
    }

    private func collectFiles() -> [URL] {
        var urls: [URL] = []
        let fm = FileManager.default

        // Scan root folder (non-recursive, skip subfolders except _rejected)
        if let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    // Only recurse into _rejected, skip other subdirectories
                    if fileURL.lastPathComponent == "_rejected" {
                        continue // let enumerator recurse into it
                    } else {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                if SupportedFormats.isSupported(fileURL) {
                    urls.append(fileURL)
                }
            }
        }

        return urls
    }

    private func processFile(url: URL) async -> MediaItem? {
        let isVideo = SupportedFormats.isVideo(url)
        let captureDate: Date

        if isVideo {
            captureDate = await videoCreationDate(url: url) ?? fileModDate(url: url)
        } else {
            captureDate = exifDate(url: url) ?? fileModDate(url: url)
        }

        let relativePath = relativeID(for: url)
        return MediaItem(url: url, captureDate: captureDate, isVideo: isVideo, id: relativePath)
    }

    /// Extract EXIF DateTimeOriginal
    private func exifDate(url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] else { return nil }
        guard let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    /// Extract video creation date from metadata
    private func videoCreationDate(url: URL) async -> Date? {
        let asset = AVAsset(url: url)
        guard let metadataItem = try? await asset.load(.creationDate) else { return nil }
        return try? await metadataItem.load(.dateValue)
    }

    /// Fallback to file modification date
    private func fileModDate(url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? Date.distantPast
    }

    /// Create a stable ID from relative path
    func relativeID(for url: URL) -> String {
        let rootPath = rootURL.path
        let filePath = url.path
        if filePath.hasPrefix(rootPath) {
            return String(filePath.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }
}
