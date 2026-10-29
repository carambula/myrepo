import Foundation

// MARK: - Per-episode ad analysis cache

/// Memoized per-episode ad analysis. Phase 0 computes from chapters only;
/// later phases plug richer detectors in behind the same interface.
///
/// Results persist as JSON sidecars so analysis survives relaunches, and
/// `analyzerVersion` invalidates them when the detector improves.
final class EpisodeAdAnalysisProvider {
    static let shared = EpisodeAdAnalysisProvider()

    private let lock = NSLock()
    private var memoryCache: [String: EpisodeAdAnalysis] = [:]
    private let cacheDirectory: URL

    init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.cacheDirectory = base.appendingPathComponent("PodLink/ad-analysis", isDirectory: true)
        }
    }

    /// Returns the cached analysis, computing and persisting it on a miss.
    /// Stale analyzer versions are recomputed transparently.
    func analysis(for episode: Episode) -> EpisodeAdAnalysis {
        let id = episode.id

        lock.lock()
        if let cached = memoryCache[id],
           cached.analyzerVersion == EpisodeAdAnalysis.currentAnalyzerVersion
        {
            lock.unlock()
            return cached
        }
        lock.unlock()

        if let disk = loadFromDisk(episodeID: id),
           disk.analyzerVersion == EpisodeAdAnalysis.currentAnalyzerVersion
        {
            lock.lock()
            memoryCache[id] = disk
            lock.unlock()
            return disk
        }

        var segments = ChapterAdDetector.detect(
            from: episode.chapters,
            episodeDuration: episode.duration
        )
        // Phase 1: merge behavior-learned segments (L1). Learned segments
        // that overlap a chapter segment are dropped in favor of the chapter
        // (higher provenance).
        let learned = AdPatternLearner.learnedSegments(for: episode.podcastID)
        for ls in learned where !segments.contains(where: { overlaps($0, ls) }) {
            segments.append(ls)
        }
        let fresh = EpisodeAdAnalysis(episodeID: id, segments: segments)
        saveToDisk(fresh)
        lock.lock()
        memoryCache[id] = fresh
        lock.unlock()
        return fresh
    }

    /// Phase 2: runs transcript-based ad detection for an episode.
    /// Transcription is expensive — call from a background task (WiFi +
    /// charging) or on-demand, not during playback. Results merge into the
    /// cached analysis; the cache is invalidated so the next read picks
    /// them up.
    func analyzeTranscript(for episode: Episode) async {
        let transcript = await TranscriptService.shared.getFullTranscript(for: episode)
        guard let transcript else { return }
        let detected = TranscriptAdClassifier.detect(from: transcript)
        guard !detected.isEmpty else { return }

        lock.lock()
        var current = memoryCache[episode.id]
        lock.unlock()
        if current == nil {
            current = loadFromDisk(episodeID: episode.id)
        }
        let existing = current?.segments ?? []
        // Merge: transcript segments that don't overlap existing ones win.
        // Existing (chapter/behavior) segments keep priority on overlap.
        var merged = existing
        for seg in detected where !merged.contains(where: { overlaps($0, seg) }) {
            merged.append(seg)
        }
        let updated = EpisodeAdAnalysis(
            episodeID: episode.id,
            segments: merged,
            analyzerVersion: EpisodeAdAnalysis.currentAnalyzerVersion
        )
        saveToDisk(updated)
        lock.lock()
        memoryCache[episode.id] = updated
        lock.unlock()
    }

    /// Drops cached analysis, e.g. when chapters arrive after first analysis.
    func invalidate(episodeID: String) {
        lock.lock()
        memoryCache.removeValue(forKey: episodeID)
        lock.unlock()
        try? FileManager.default.removeItem(at: fileURL(for: episodeID))
    }

    // MARK: - Disk cache

    private func fileURL(for episodeID: String) -> URL {
        let safe = episodeID.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            ?? UUID().uuidString
        return cacheDirectory.appendingPathComponent("\(safe).json")
    }

    private func loadFromDisk(episodeID: String) -> EpisodeAdAnalysis? {
        guard let data = try? Data(contentsOf: fileURL(for: episodeID)) else { return nil }
        return try? JSONDecoder().decode(EpisodeAdAnalysis.self, from: data)
    }

    /// Two segments overlap if their ranges intersect.
    private func overlaps(_ a: AdSegment, _ b: AdSegment) -> Bool {
        max(a.startTime, b.startTime) < min(a.endTime, b.endTime)
    }

    private func saveToDisk(_ analysis: EpisodeAdAnalysis) {
        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(analysis)
            try data.write(to: fileURL(for: analysis.episodeID), options: .atomic)
        } catch {
            // Cache is best-effort; analysis recomputes on the next read.
        }
    }
}
