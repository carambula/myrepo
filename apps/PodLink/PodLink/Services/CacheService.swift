import Foundation

actor CacheService {
    static let shared = CacheService()

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private let defaultTTL: TimeInterval = 24 * 60 * 60 // 24 hours

    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("PodLinkCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 200
    }

    func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        let nsKey = NSString(string: key)

        if let entry = memoryCache.object(forKey: nsKey),
           !entry.isExpired,
           let value = try? JSONDecoder().decode(T.self, from: entry.data) {
            return value
        }

        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let diskEntry = try? JSONDecoder().decode(DiskCacheEntry.self, from: data),
              !diskEntry.isExpired else {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        if let value = try? JSONDecoder().decode(T.self, from: diskEntry.data) {
            memoryCache.setObject(CacheEntry(data: diskEntry.data, expiry: diskEntry.expiry), forKey: nsKey)
            return value
        }
        return nil
    }

    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval? = nil) {
        let expiry = Date().addingTimeInterval(ttl ?? defaultTTL)
        guard let data = try? JSONEncoder().encode(value) else { return }

        let nsKey = NSString(string: key)
        memoryCache.setObject(CacheEntry(data: data, expiry: expiry), forKey: nsKey)

        let diskEntry = DiskCacheEntry(data: data, expiry: expiry)
        if let diskData = try? JSONEncoder().encode(diskEntry) {
            let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
            try? diskData.write(to: fileURL)
        }
    }

    func remove(_ key: String) {
        memoryCache.removeObject(forKey: NSString(string: key))
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256Hash)
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

private class CacheEntry: NSObject {
    let data: Data
    let expiry: Date
    var isExpired: Bool { Date() > expiry }

    init(data: Data, expiry: Date) {
        self.data = data
        self.expiry = expiry
    }
}

private struct DiskCacheEntry: Codable {
    let data: Data
    let expiry: Date
    var isExpired: Bool { Date() > expiry }
}

extension String {
    var sha256Hash: String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            var hasher = SimpleHasher()
            hasher.combine(bytes: buffer)
            hash = hasher.finalize()
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

private struct SimpleHasher {
    private var value: UInt64 = 0xcbf29ce484222325

    mutating func combine(bytes: UnsafeRawBufferPointer) {
        for byte in bytes {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
    }

    func finalize() -> [UInt8] {
        var result = [UInt8](repeating: 0, count: 32)
        var v = value
        for i in 0..<8 {
            result[i] = UInt8(v & 0xFF)
            v >>= 8
        }
        v = value &* 0x517cc1b727220a95
        for i in 8..<16 {
            result[i] = UInt8(v & 0xFF)
            v >>= 8
        }
        v = value &* 0x6c62272e07bb0142
        for i in 16..<24 {
            result[i] = UInt8(v & 0xFF)
            v >>= 8
        }
        v = value &* 0x62b821756295c58d
        for i in 24..<32 {
            result[i] = UInt8(v & 0xFF)
            v >>= 8
        }
        return result
    }
}
