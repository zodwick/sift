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
        let aspectRatio: CGFloat

        if isVideo {
            captureDate = await videoCreationDate(url: url) ?? fileModDate(url: url)
            aspectRatio = await videoAspectRatio(url: url)
        } else {
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
            captureDate = exifDate(source: source) ?? fileModDate(url: url)
            aspectRatio = imageAspectRatio(source: source)
        }

        let relativePath = relativeID(for: url)
        return MediaItem(url: url, captureDate: captureDate, isVideo: isVideo, id: relativePath, aspectRatio: aspectRatio)
    }

    /// Extract EXIF DateTimeOriginal from an already-created CGImageSource
    private func exifDate(source: CGImageSource?) -> Date? {
        guard let source = source else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] else { return nil }
        guard let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    /// Extract aspect ratio from image pixel dimensions (EXIF only, no decode)
    private func imageAspectRatio(source: CGImageSource?) -> CGFloat {
        guard let source = source,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              height > 0
        else { return 1.0 }

        // Account for EXIF orientation — values 5-8 swap width/height
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        if orientation >= 5 && orientation <= 8 {
            return height / width
        }
        return width / height
    }

    /// Extract aspect ratio from video track natural size
    private func videoAspectRatio(url: URL) async -> CGFloat {
        let asset = AVAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return 1.0 }
        let size = try? await track.load(.naturalSize)
        guard let size = size, size.height > 0 else { return 1.0 }
        // Apply preferred transform to handle rotated videos
        let transform = (try? await track.load(.preferredTransform)) ?? .identity
        let transformedSize = CGSize(width: size.width, height: size.height).applying(transform)
        return abs(transformedSize.width) / abs(transformedSize.height)
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

    /// Create a stable ID from relative path (strips _rejected/ so IDs stay consistent after moves)
    func relativeID(for url: URL) -> String {
        let rootPath = rootURL.path
        let filePath = url.path
        if filePath.hasPrefix(rootPath) {
            var relative = String(filePath.dropFirst(rootPath.count + 1))
            if relative.hasPrefix("_rejected/") {
                relative = String(relative.dropFirst("_rejected/".count))
            }
            return relative
        }
        return url.lastPathComponent
    }
}
