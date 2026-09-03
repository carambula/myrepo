//
//  ImageCache.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import SwiftUI

public class ImageCache {
    public static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let diskQueue = DispatchQueue(label: "WatchedIt.ImageCache.disk", qos: .utility)
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Setup in-memory cache with optimized limits
        cache.countLimit = 200 // Increased for better cache hit rate
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB for smoother scrolling
        
        // Setup disk cache directory
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("MovieImages", isDirectory: true)
        
        // Create directory if it doesn't exist
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
    
    public func getImage(for url: URL) -> UIImage? {
        // Check memory cache first
        if let image = cache.object(forKey: url.absoluteString as NSString) {
            return image
        }

        return nil
    }

    public func getImageAsync(for url: URL) async -> UIImage? {
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
    
    public func setImage(_ image: UIImage, for url: URL) {
        // Calculate cost based on image size (width * height * 4 bytes per pixel)
        let cost = Int(image.size.width * image.size.height * 4)
        
        // Store in memory cache with cost
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
        
        // Store in disk cache asynchronously
        Task.detached { [weak self] in
            self?.saveToDisk(image: image, url: url)
        }
    }
    
    /// Prefetch an image from URL if not already cached
    public func prefetchImage(from url: URL) async {
        guard isSupportedRemoteURL(url) else { return }
        // Check if already cached
        if await getImageAsync(for: url) != nil {
            return
        }
        
        // Download and cache
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else { return }
            }
            
            if let uiImage = UIImage(data: data),
               uiImage.size.width > 0 && uiImage.size.height > 0 {
                setImage(uiImage, for: url)
            }
        } catch {
            // Silently handle errors
        }
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
    
    public func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

