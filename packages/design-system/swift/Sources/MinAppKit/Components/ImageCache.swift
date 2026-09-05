#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// Shared image cache with NSCache (memory) and disk persistence.
///
/// Each app provides its own directory name to avoid collisions:
/// ```swift
/// // In your app's setup:
/// ImageCache.shared = ImageCache(directoryName: "MyAppImages")
/// ```
public final class ImageCache: @unchecked Sendable {
    public static var shared = ImageCache(directoryName: "MinAppImages")

    private let cache = NSCache<NSString, UIImage>()
    private let diskCacheDirectory: URL
    private let diskQueue: DispatchQueue

    /// Maximum decoded pixel dimension. Images larger than this are downscaled on cache insertion.
    /// Set to `nil` to disable downscaling.
    public var maxDecodedPixelSide: CGFloat?

    public init(directoryName: String, maxDecodedPixelSide: CGFloat? = nil) {
        self.maxDecodedPixelSide = maxDecodedPixelSide

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskCacheDirectory = cacheDir.appendingPathComponent(directoryName)
        self.diskQueue = DispatchQueue(label: "MinAppKit.ImageCache.\(directoryName)", qos: .utility)

        cache.totalCostLimit = 100 * 1024 * 1024
        cache.countLimit = 200

        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    public func getImage(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let diskPath = diskCacheDirectory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: diskPath),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            return image
        }

        return nil
    }

    public func setImage(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        let normalized = normalizeIfNeeded(image)
        cache.setObject(normalized, forKey: key as NSString)

        diskQueue.async { [weak self] in
            guard let self else { return }
            let diskPath = self.diskCacheDirectory.appendingPathComponent(key)
            if let data = normalized.jpegData(compressionQuality: 0.8) {
                try? data.write(to: diskPath)
            }
        }
    }

    @discardableResult
    public func prefetchImage(from url: URL) async -> UIImage? {
        if let cached = getImage(for: url) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            setImage(image, for: url)
            return image
        } catch {
            return nil
        }
    }

    public func clearCache() {
        cache.removeAllObjects()
        diskQueue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.diskCacheDirectory)
            try? FileManager.default.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
        }
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    private func normalizeIfNeeded(_ image: UIImage) -> UIImage {
        guard let maxSide = maxDecodedPixelSide else { return image }
        let size = image.size
        guard max(size.width, size.height) > maxSide else { return image }

        let scale = maxSide / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
