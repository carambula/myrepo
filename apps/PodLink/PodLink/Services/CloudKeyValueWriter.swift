import Foundation

extension Notification.Name {
    /// Posted on the main thread after the in-memory iCloud mirror hydrates or external changes land.
    static let cloudKeyValueStoreDidChange = Notification.Name("PodLink.cloudKeyValueStoreDidChange")
}

/// In-memory mirror of `NSUbiquitousKeyValueStore` so the main thread never blocks on iCloud.
///
/// KVS reads are cheap once the store is loaded, but the *first* access lazily loads the store and
/// `synchronize()` can block the calling thread for seconds while it reaches the ubiquity daemon /
/// network. Because this app's stores run on the main actor (`SWIFT_DEFAULT_ACTOR_ISOLATION =
/// MainActor`), that blocked the UI on launch. This type does all real KVS work on a background
/// queue and serves synchronous reads/writes from an in-memory dictionary, so callers never touch
/// `NSUbiquitousKeyValueStore.default` on the main thread.
enum CloudKeyValueWriter {
    nonisolated private static let queue = DispatchQueue(label: "PodLink.CloudKeyValueStore", qos: .utility)
    nonisolated private static let lock = NSLock()
    /// Guarded by `lock`.
    nonisolated(unsafe) private static var mirror: [String: Any] = [:]

    // MARK: - Lifecycle

    /// Hydrates the mirror and begins observing external iCloud changes. Call once at launch.
    nonisolated static func start() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: nil
        ) { note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            refreshFromStore(changedKeys: keys)
        }

        queue.async {
            let store = NSUbiquitousKeyValueStore.default
            store.synchronize()
            let snapshot = store.dictionaryRepresentation
            lock.lock()
            for (key, value) in snapshot where mirror[key] == nil {
                mirror[key] = value
            }
            lock.unlock()
            postDidChange()
        }
    }

    private nonisolated static func refreshFromStore(changedKeys: [String]?) {
        queue.async {
            let store = NSUbiquitousKeyValueStore.default
            lock.lock()
            if let changedKeys {
                for key in changedKeys { mirror[key] = store.object(forKey: key) }
            } else {
                for (key, value) in store.dictionaryRepresentation { mirror[key] = value }
            }
            lock.unlock()
            postDidChange()
        }
    }

    private nonisolated static func postDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cloudKeyValueStoreDidChange, object: nil)
        }
    }

    // MARK: - Reads (memory-only; never block the caller)

    nonisolated static func data(forKey key: String) -> Data? { value(forKey: key) as? Data }

    nonisolated static func object(forKey key: String) -> Any? { value(forKey: key) }

    nonisolated static func double(forKey key: String) -> Double {
        (value(forKey: key) as? NSNumber)?.doubleValue ?? 0
    }

    nonisolated static func bool(forKey key: String) -> Bool {
        (value(forKey: key) as? NSNumber)?.boolValue ?? false
    }

    private nonisolated static func value(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        return mirror[key]
    }

    // MARK: - Writes (update mirror immediately, persist to iCloud off the main thread)

    nonisolated static func setData(_ data: Data, forKey key: String) { write(data, forKey: key) }

    nonisolated static func setString(_ value: String, forKey key: String) { write(value, forKey: key) }

    nonisolated static func setDouble(_ value: Double, forKey key: String) { write(value as NSNumber, forKey: key) }

    nonisolated static func setBool(_ value: Bool, forKey key: String) { write(value as NSNumber, forKey: key) }

    nonisolated static func removeObject(forKey key: String) {
        lock.lock(); mirror.removeValue(forKey: key); lock.unlock()
        queue.async { NSUbiquitousKeyValueStore.default.removeObject(forKey: key) }
    }

    private nonisolated static func write(_ value: Any, forKey key: String) {
        lock.lock(); mirror[key] = value; lock.unlock()
        queue.async { NSUbiquitousKeyValueStore.default.set(value, forKey: key) }
    }
}
