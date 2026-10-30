import Foundation

// MARK: - Seek event logging (Phase 0 records; Phase 3 learns)

/// How a seek was triggered. Recorded so Phase 3 can mine
/// skip-forward-then-back patterns without extra instrumentation.
enum SeekTrigger: String, Codable {
    case forwardButton
    case backButton
    case remote
    case scrub
}

/// One seek. On-device only — never uploaded.
struct SeekEvent: Identifiable, Codable {
    let id: String
    let episodeID: String
    let podcastID: String
    let fromTime: TimeInterval
    let toTime: TimeInterval
    let trigger: SeekTrigger
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        episodeID: String,
        podcastID: String,
        fromTime: TimeInterval,
        toTime: TimeInterval,
        trigger: SeekTrigger,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.episodeID = episodeID
        self.podcastID = podcastID
        self.fromTime = fromTime
        self.toTime = toTime
        self.trigger = trigger
        self.timestamp = timestamp
    }
}

/// Append-only ring buffer of seek events, persisted as JSON.
/// Thread-safe; writes are debounced to one disk write per log call,
/// which is fine because seeks are user-driven and infrequent.
final class SeekEventStore {
    static let shared = SeekEventStore()

    private let maxEvents = 2000
    private let fileURL: URL
    private let lock = NSLock()
    private var events: [SeekEvent] = []

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base.appendingPathComponent("PodLink/seek-events.json")
        }
        load()
    }

    func log(
        episodeID: String,
        podcastID: String,
        from fromTime: TimeInterval,
        to toTime: TimeInterval,
        trigger: SeekTrigger
    ) {
        guard abs(toTime - fromTime) >= 1 else { return } // ignore no-op seeks
        lock.lock()
        events.append(SeekEvent(
            episodeID: episodeID,
            podcastID: podcastID,
            fromTime: fromTime,
            toTime: toTime,
            trigger: trigger
        ))
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        let snapshot = events
        lock.unlock()
        save(snapshot)
    }

    /// Most recent events for a show, oldest-first, capped at `limit`.
    func recentEvents(forPodcastID podcastID: String, limit: Int = 500) -> [SeekEvent] {
        lock.lock()
        defer { lock.unlock() }
        return Array(events.filter { $0.podcastID == podcastID }.suffix(limit))
    }

    func clear() {
        lock.lock()
        events = []
        lock.unlock()
        save([])
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([SeekEvent].self, from: data)
        else { return }
        lock.lock()
        events = Array(decoded.suffix(maxEvents))
        lock.unlock()
    }

    private func save(_ snapshot: [SeekEvent]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Event log is best-effort; a failed write just drops history.
        }
    }
}
