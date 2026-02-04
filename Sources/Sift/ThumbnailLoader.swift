import AppKit
import ImageIO
import AVFoundation

final class ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private let thumbnailCache = NSCache<NSString, NSImage>()
    private let galleryCache = NSCache<NSString, NSImage>()
    private let previewCache = NSCache<NSString, NSImage>()

    init() {
        thumbnailCache.countLimit = 500
        galleryCache.countLimit = 200
        previewCache.countLimit = 20
    }

    /// Generate a thumbnail (~150px) for filmstrip
    func thumbnail(for item: MediaItem, size: CGFloat = 150) async -> NSImage? {
        let cacheKey = "\(item.id)_thumb" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        let image: NSImage?
        if item.isVideo {
            image = await videoThumbnail(url: item.url, size: size)
        } else {
            image = await imageThumbnail(url: item.url, size: size)
        }

        if let image = image {
            thumbnailCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    /// Generate a gallery thumbnail (~440px) for masonry grid — matches ~220pt columns at 2x Retina
    func galleryThumbnail(for item: MediaItem, size: CGFloat = 440) async -> NSImage? {
        let cacheKey = "\(item.id)_gallery" as NSString
        if let cached = galleryCache.object(forKey: cacheKey) {
            return cached
        }

        let image: NSImage?
        if item.isVideo {
            image = await videoThumbnail(url: item.url, size: size)
        } else {
            image = await imageThumbnail(url: item.url, size: size)
        }

        if let image = image {
            galleryCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    /// Generate a preview (~2000px) for main display
    func preview(for item: MediaItem, size: CGFloat = 2000) async -> NSImage? {
        let cacheKey = "\(item.id)_preview" as NSString
        if let cached = previewCache.object(forKey: cacheKey) {
            return cached
        }

        let image: NSImage?
        if item.isVideo {
            image = await videoThumbnail(url: item.url, size: size)
        } else {
            image = await imageThumbnail(url: item.url, size: size)
        }

        if let image = image {
            previewCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    /// Full resolution image for zoom — capped at 4000px to avoid loading 100MB+ RAW bitmaps
    func fullResolution(for item: MediaItem) async -> NSImage? {
        guard !item.isVideo else { return nil }

        let url = item.url
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: 4000,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                ]

                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let nsImage = NSImage(cgImage: cgImage, size: NSSize(
                    width: cgImage.width,
                    height: cgImage.height
                ))
                continuation.resume(returning: nsImage)
            }
        }
    }

    private func imageThumbnail(url: URL, size: CGFloat) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let options: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: size,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                ]

                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let nsImage = NSImage(cgImage: cgImage, size: NSSize(
                    width: cgImage.width,
                    height: cgImage.height
                ))
                continuation.resume(returning: nsImage)
            }
        }
    }

    private func videoThumbnail(url: URL, size: CGFloat) async -> NSImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: size, height: size)

                let time = CMTime(seconds: 0, preferredTimescale: 600)
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(
                        width: cgImage.width,
                        height: cgImage.height
                    ))
                    continuation.resume(returning: nsImage)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
