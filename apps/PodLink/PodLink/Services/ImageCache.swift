import Foundation
import UIKit
import ImageIO

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let diskQueue = DispatchQueue(label: "PodLink.ImageCache.disk", qos: .utility)
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private static let maxDecodedPixelSide: CGFloat = 900

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024

        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("PodLinkImages", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    private func isSupportedRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return false
        }
        return true
    }

    func getImage(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func getImageAsync(for url: URL) async -> UIImage? {
        if let image = getImage(for: url) {
            return image
        }

        return await withCheckedContinuation { continuation in
            diskQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                guard let image = self.loadFromDisk(url: url) else {
                    continuation.resume(returning: nil)
                    return
                }
                let cost = Int(image.size.width * image.size.height * 4)
                self.cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
                continuation.resume(returning: image)
            }
        }
    }

    func setImage(_ image: UIImage, for url: URL) {
        let normalized = normalizeImageForCache(image)
        let cost = Int(normalized.size.width * normalized.size.height * 4)
        cache.setObject(normalized, forKey: url.absoluteString as NSString, cost: cost)

        Task.detached { [weak self] in
            self?.saveToDisk(image: normalized, url: url)
        }
    }

    func prefetchImage(from url: URL) async {
        guard isSupportedRemoteURL(url) else { return }
        if await getImageAsync(for: url) != nil {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else { return }
            }

            if let decoded = decodeImage(data: data),
               decoded.size.width > 0 && decoded.size.height > 0 {
                setImage(decoded, for: url)
            }
        } catch {}
    }

    private func normalizeImageForCache(_ image: UIImage) -> UIImage {
        let maxSide = Self.maxDecodedPixelSide
        let w = image.size.width
        let h = image.size.height
        guard max(w, h) > maxSide else { return image }
        let scale = maxSide / max(w, h)
        let newSize = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func decodeImage(data: Data) -> UIImage? {
        let maxSide = Self.maxDecodedPixelSide
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    private func loadFromDisk(url: URL) -> UIImage? {
        let fileName = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    nonisolated private func saveToDisk(image: UIImage, url: URL) {
        let fileName = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: fileURL)
    }

    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
