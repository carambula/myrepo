import Foundation
import AVFoundation
import MediaPlayer
import Observation
import UIKit

@Observable
class PlaybackService {
    static let shared = PlaybackService()

    /// Must match `@AppStorage("preferVideoPlayback")` in `PlaybackSettingsView`.
    private static let preferVideoPlaybackUserDefaultsKey = "preferVideoPlayback"

    private static let autoQueueMetadataIndexingEnabledUserDefaultsKey = "autoQueueMetadataIndexingEnabled"

    static func autoQueueMetadataIndexingEnabledFromDefaults() -> Bool {
        UserDefaults.standard.object(forKey: autoQueueMetadataIndexingEnabledUserDefaultsKey) as? Bool ?? true
    }

    /// Must match `@AppStorage("playbackSpeed")` in `PlaybackSettingsView`.
    private static let playbackSpeedUserDefaultsKey = "playbackSpeed"

    /// Persisted so cold launch can show the mini player with the last episode and scrub position.
    private static let lastResumeSessionDefaultsKey = "lastPlaybackResumeSessionV1"

    private struct LastResumeSessionArchive: Codable {
        var episode: Episode
        var podcast: Podcast
    }

    let state = PlaybackState()

    /// Drives the app-level now-playing `EpisodePlayerSheet` (over the main stack or over another root sheet).
    var isNowPlayingSheetPresented = false

    /// Nested `onAppear` / `onDisappear` from every `EpisodePlayerSheet`; hides the mini player while > 0.
    private(set) var episodePlayerUIPresentationDepth = 0

    var isEpisodePlayerUIVisible: Bool { episodePlayerUIPresentationDepth > 0 }

    func pushEpisodePlayerUISession() {
        episodePlayerUIPresentationDepth += 1
    }

    func popEpisodePlayerUISession() {
        episodePlayerUIPresentationDepth = max(0, episodePlayerUIPresentationDepth - 1)
    }

    /// Hides the floating mini player while any search screen is on-screen.
    private(set) var searchUIPresentationDepth = 0

    var isSearchUIVisible: Bool { searchUIPresentationDepth > 0 }

    var isPlaybackStartupInProgress: Bool {
        state.isBuffering || (state.isPlaying && player?.timeControlStatus != .playing)
    }

    func pushSearchUISession() {
        searchUIPresentationDepth += 1
    }

    func popSearchUISession() {
        searchUIPresentationDepth = max(0, searchUIPresentationDepth - 1)
    }

    /// `AVAudioSession.setActive(_:)` can block the caller for seconds, so activation always runs here,
    /// never on the main thread.
    nonisolated private static let audioSessionQueue = DispatchQueue(label: "PodLink.AudioSession", qos: .userInitiated)

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var startupSeekTask: Task<Void, Never>?
    /// Observes the current item's `status` so the startup resume-seek fires the moment it is ready.
    private var startupSeekStatusObservation: NSKeyValueObservation?
    /// Bumped on every schedule/cancel so the startup resume-seek fires at most once per session and a
    /// later `.readyToPlay` transition (rebuffer/stall recovery) can never re-seek to the stale start.
    private var startupSeekToken = 0
    private var positionSaveTask: Task<Void, Never>?
    private var nowPlayingArtworkTask: Task<Void, Never>?
    /// Dedupes lock-screen artwork fetches across frequent `updateNowPlayingInfo` calls (seeks, time observer).
    private var lastNowPlayingArtworkKey: String?
    private var endPlaybackObserver: NSObjectProtocol?
    private var audioInterruptionObserver: NSObjectProtocol?
    private var timeControlStatusObservation: NSKeyValueObservation?
    /// Captures whether we were actively playing before a system interruption began.
    private var shouldResumeAfterInterruption = false

    init() {
        state.playbackRate = Self.preferredPlaybackRateFromDefaults()
        observeAudioSessionInterruptions()
    }

    deinit {
        removeAudioSessionInterruptionObserver()
    }

    // MARK: - Core Playback

    func play(episode: Episode, podcast: Podcast? = nil, startAt: TimeInterval? = nil) async {
        state.playbackRate = Self.preferredPlaybackRateFromDefaults()
        var merged = EpisodePlaybackStore.merge(episode)
        if let localURL = merged.downloadedFileURL,
           !FileManager.default.fileExists(atPath: localURL.path) {
            if let record = DownloadMetadataStore.record(for: merged) {
                DownloadMetadataStore.remove(record: record)
            }
            merged.isDownloaded = false
            merged.downloadedFileURL = nil
        }
        let url = merged.downloadedFileURL ?? merged.audioURL

        let playerItem = AVPlayerItem(url: url)

        removePlaybackEndObserver()
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        observePlaybackEnd(for: playerItem)

        nowPlayingArtworkTask?.cancel()
        lastNowPlayingArtworkKey = nil
        state.currentEpisode = merged
        state.currentPodcast = podcast
        applyPreferredVideoMode(for: merged)
        state.isPlaying = true
        state.currentTime = startAt ?? merged.playbackPosition
        state.duration = merged.duration
        state.isBuffering = true

        setupTimeObserver()
        observeTimeControlStatus()
        player?.automaticallyWaitsToMinimizeStalling = false
        await activateAudioSessionForPlayback()
        player?.playImmediately(atRate: state.playbackRate)
        if let startTime = startAt ?? (merged.playbackPosition > 0 ? merged.playbackPosition : nil) {
            scheduleStartupSeek(to: startTime, episodeID: merged.id)
        }
        updateNowPlayingInfo()
        configureRemoteCommands()
        startPositionSaving()
        EpisodePlaybackStore.recordLastPlayedEpisode(episodeID: merged.id, podcastID: merged.podcastID)
        saveResumeSessionNowIfOnMainActor()
    }

    func pause() {
        player?.pause()
        state.isPlaying = false
        state.isBuffering = false
        cancelStartupSeek()
        positionSaveTask?.cancel()
        updateNowPlayingInfo()
        Task {
            await persistPlaybackProgress()
            await MainActor.run { persistResumeSessionArchiveFromCurrentState() }
        }
    }

    func resume() {
        guard state.currentEpisode != nil else { return }
        if player?.currentItem == nil {
            let episode = state.currentEpisode!
            let podcast = state.currentPodcast
            let startAt = state.currentTime
            Task(priority: .userInitiated) { await play(episode: episode, podcast: podcast, startAt: startAt) }
            return
        }
        activateAudioSessionForPlaybackDetached()
        player?.play()
        player?.rate = state.playbackRate
        state.isPlaying = true
        startPositionSaving()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if state.isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        if let player {
            player.seek(to: cmTime) { [weak self] _ in
                self?.state.currentTime = time
                self?.updateNowPlayingInfo()
            }
        } else {
            state.currentTime = time
            updateNowPlayingInfo()
            Task {
                await persistPlaybackProgress()
            }
        }
    }

    func skipForward(seconds: TimeInterval = 30) {
        let newTime = min(state.currentTime + seconds, state.duration)
        seek(to: newTime)
    }

    func skipBackward(seconds: TimeInterval = 15) {
        let newTime = max(state.currentTime - seconds, 0)
        seek(to: newTime)
    }

    func setRate(_ rate: Float) {
        state.playbackRate = rate
        Self.persistPlaybackSpeed(rate)
        if state.isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }

    private static func preferredPlaybackRateFromDefaults() -> Float {
        guard let object = UserDefaults.standard.object(forKey: playbackSpeedUserDefaultsKey) else {
            return 1.0
        }
        let value: Double
        if let d = object as? Double {
            value = d
        } else if let f = object as? Float {
            value = Double(f)
        } else if let n = object as? NSNumber {
            value = n.doubleValue
        } else {
            return 1.0
        }
        return Float(min(max(value, 0.5), 3.0))
    }

    private static func persistPlaybackSpeed(_ rate: Float) {
        UserDefaults.standard.set(Double(rate), forKey: playbackSpeedUserDefaultsKey)
    }

    /// Synchronous audio-session work. MUST run on `audioSessionQueue`, never the main thread:
    /// `setActive(_:)` reaches the media daemon and can block for seconds, which on the MainActor
    /// surfaced as multi-second hangs whenever playback started.
    nonisolated private static func activatePlaybackAudioSessionSync() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session for playback: \(error)")
        }
    }

    /// Awaitable activation for the async play path: preserves "activate before play" ordering while
    /// keeping the main thread free (the `await` suspends instead of blocking).
    private func activateAudioSessionForPlayback() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Self.audioSessionQueue.async {
                Self.activatePlaybackAudioSessionSync()
                continuation.resume()
            }
        }
    }

    /// Fire-and-forget activation for synchronous callers (resume, interruption recovery).
    private func activateAudioSessionForPlaybackDetached() {
        Self.audioSessionQueue.async {
            Self.activatePlaybackAudioSessionSync()
        }
    }

    func stop() {
        player?.pause()
        removePlaybackEndObserver()
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil
        player?.replaceCurrentItem(with: nil)
        removeTimeObserver()
        cancelStartupSeek()
        state.currentEpisode = nil
        state.currentPodcast = nil
        state.isPlaying = false
        state.isBuffering = false
        state.currentTime = 0
        state.duration = 0
        positionSaveTask?.cancel()
        nowPlayingArtworkTask?.cancel()
        nowPlayingArtworkTask = nil
        lastNowPlayingArtworkKey = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UserDefaults.standard.removeObject(forKey: Self.lastResumeSessionDefaultsKey)
    }

    // MARK: - Resume session (mini player after relaunch)

    /// Call from the main thread (e.g. `scenePhase` → background) so the snapshot is flushed before suspension.
    func saveResumeSessionNow() {
        assert(Thread.isMainThread)
        persistResumeSessionArchiveFromCurrentState()
    }

    /// Restores `state` without loading `AVPlayer` so the mini player shows correct artwork, title, and progress; playback starts on play.
    func restoreResumeSessionIfNeeded() async {
        guard state.currentEpisode == nil else { return }

        // Decode the archive, load followed podcasts, and merge stored progress off the main thread.
        // These are JSON decodes plus `EpisodePlaybackStore`/`DownloadMetadataStore` disk reads that
        // previously ran synchronously on the MainActor at launch.
        let restored = await Task.detached(priority: .userInitiated) { () -> (Podcast, Episode, Episode)? in
            guard let data = UserDefaults.standard.data(forKey: Self.lastResumeSessionDefaultsKey),
                  let archive = try? JSONDecoder().decode(LastResumeSessionArchive.self, from: data)
            else { return nil }

            let followed = Podcast.loadFollowedPodcasts()
            let resolvedPodcast =
                followed.first { $0.id == archive.podcast.id || $0.feedURL == archive.podcast.feedURL } ?? archive.podcast
            let mergedEpisode = EpisodePlaybackStore.merge(archive.episode)
            return (resolvedPodcast, mergedEpisode, archive.episode)
        }.value

        guard let (resolvedPodcast, mergedEpisode, archiveEpisode) = restored else { return }
        // Re-check after the suspension: playback may have started while we were decoding.
        guard state.currentEpisode == nil else { return }

        state.currentPodcast = resolvedPodcast
        state.currentEpisode = mergedEpisode
        state.currentTime = mergedEpisode.playbackPosition
        state.duration = mergedEpisode.duration > 0 ? mergedEpisode.duration : archiveEpisode.duration
        state.isPlaying = false
        state.isBuffering = false
        applyPreferredVideoMode(for: mergedEpisode)

        refreshRestoredResumeSessionIfNeeded(
            archive: LastResumeSessionArchive(episode: archiveEpisode, podcast: resolvedPodcast)
        )
    }

    private func refreshRestoredResumeSessionIfNeeded(archive: LastResumeSessionArchive) {
        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            let followed = Podcast.loadFollowedPodcasts()
            guard let subscribed = followed.first(where: {
                $0.feedURL.absoluteString == archive.episode.podcastID || $0.id == archive.episode.podcastID
            }) else { return }

            let fetched: [Episode]
            if let cached = await RSSFeedService.shared.cachedEpisodes(feedURL: subscribed.feedURL) {
                fetched = cached
            } else {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled,
                      self.player?.currentItem == nil,
                      !self.state.isPlaying,
                      self.state.currentEpisode?.id == archive.episode.id else { return }
                do {
                    fetched = try await RSSFeedService.shared.fetchEpisodes(feedURL: subscribed.feedURL)
                } catch {
                    return
                }
            }

            guard let fresh = fetched.first(where: { $0.id == archive.episode.id }) else { return }
            let mergedEpisode = EpisodePlaybackStore.merge(fresh)

            await MainActor.run {
                guard self.player?.currentItem == nil,
                      !self.state.isPlaying,
                      self.state.currentEpisode?.id == archive.episode.id else { return }

                let resolvedPodcast =
                    followed.first { $0.id == archive.podcast.id || $0.feedURL == archive.podcast.feedURL } ?? archive.podcast

                self.state.currentPodcast = resolvedPodcast
                self.state.currentEpisode = mergedEpisode
                self.state.currentTime = mergedEpisode.playbackPosition
                self.state.duration = mergedEpisode.duration > 0 ? mergedEpisode.duration : archive.episode.duration
                self.applyPreferredVideoMode(for: mergedEpisode)
            }
        }
    }

    private func podcastForResumeArchive(episode: Episode) -> Podcast {
        if let p = state.currentPodcast {
            return p
        }
        if let p = Podcast.loadFollowedPodcasts().first(where: {
            $0.feedURL.absoluteString == episode.podcastID || $0.id == episode.podcastID
        }) {
            return p
        }
        let feed = URL(string: episode.podcastID) ?? URL(fileURLWithPath: "/")
        return Podcast(title: "", author: "", feedURL: feed)
    }

    private func persistResumeSessionArchiveFromCurrentState() {
        guard let episode = state.currentEpisode else {
            UserDefaults.standard.removeObject(forKey: Self.lastResumeSessionDefaultsKey)
            return
        }
        let archive = LastResumeSessionArchive(episode: episode, podcast: podcastForResumeArchive(episode: episode))
        guard let data = try? JSONEncoder().encode(archive) else { return }
        UserDefaults.standard.set(data, forKey: Self.lastResumeSessionDefaultsKey)
    }

    private func saveResumeSessionNowIfOnMainActor() {
        if Thread.isMainThread {
            persistResumeSessionArchiveFromCurrentState()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.persistResumeSessionArchiveFromCurrentState()
            }
        }
    }

    // MARK: - Queue Management

    func addToQueue(_ episode: Episode) {
        let merged = EpisodePlaybackStore.merge(episode)
        if !state.queue.contains(where: { $0.id == merged.id }) {
            state.queue.append(merged)
        }
    }

    func removeFromQueue(_ episode: Episode) {
        state.queue.removeAll { $0.id == episode.id }
    }

    func playNext(_ episode: Episode) {
        let merged = EpisodePlaybackStore.merge(episode)
        removeFromQueue(merged)
        state.queue.insert(merged, at: 0)
    }

    func clearQueue() {
        state.queue.removeAll()
    }

    func playNextInQueue() async {
        guard !state.queue.isEmpty else {
            stop()
            return
        }
        let next = state.queue.removeFirst()
        await play(episode: next, podcast: podcastForArtwork(episode: next))
    }

    /// Rebuilds Up Next on app launch with one latest unfinished episode per followed podcast.
    /// Order follows `Podcast.loadFollowedPodcasts()`, which is the home-grid order.
    /// When `prefetchedFeeds` is provided, uses those instead of fetching from the network.
    func queueLatestUnfinishedFromFollowedPodcasts(prefetchedFeeds: [String: [Episode]]? = nil) async {
        let followed = Podcast.loadFollowedPodcasts()
        guard !followed.isEmpty else {
            await MainActor.run { state.queue = [] }
            return
        }

        let currentID = await MainActor.run { state.currentEpisode?.id }

        let feedMap: [String: [Episode]]
        if let prefetchedFeeds {
            feedMap = prefetchedFeeds
        } else {
            feedMap = await withTaskGroup(of: (String, [Episode])?.self, returning: [String: [Episode]].self) { group in
                for podcast in followed {
                    group.addTask {
                        guard let episodes = try? await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL) else { return nil }
                        return (podcast.id, episodes)
                    }
                }
                var map: [String: [Episode]] = [:]
                for await result in group {
                    guard let (id, episodes) = result else { continue }
                    map[id] = episodes
                }
                return map
            }
        }

        // Merging every fetched episode runs `EpisodePlaybackStore.merge` (UserDefaults reads, SHA-256
        // key hashing, and `FileManager` download lookups) across all followed feeds. That is pure,
        // main-thread-free work, so it runs off the main actor (matching `restoreResumeSessionIfNeeded`)
        // to avoid a multi-second launch hang once the feeds resolve.
        let rebuiltQueue = await Task.detached(priority: .userInitiated) { () -> [Episode] in
            var seenEpisodeIDs = Set<String>()
            var rebuilt: [Episode] = []

            for podcast in followed {
                guard let fetched = feedMap[podcast.id] else { continue }
                let merged = fetched
                    .map { EpisodePlaybackStore.merge($0) }
                    .sorted { $0.publishDate > $1.publishDate }
                guard let latestUnfinished = merged.first(where: { !$0.isEffectivelyFinished }) else { continue }
                guard latestUnfinished.id != currentID else { continue }
                guard !seenEpisodeIDs.contains(latestUnfinished.id) else { continue }
                seenEpisodeIDs.insert(latestUnfinished.id)
                rebuilt.append(latestUnfinished)
            }
            return rebuilt
        }.value

        guard !Task.isCancelled else { return }
        await MainActor.run { state.queue = rebuiltQueue }
    }

    // MARK: - Video

    private func applyPreferredVideoMode(for episode: Episode) {
        let preferVideo =
            UserDefaults.standard.object(forKey: Self.preferVideoPlaybackUserDefaultsKey) as? Bool ?? false
        if preferVideo, episode.videoURL != nil {
            state.isVideoMode = true
        } else {
            state.isVideoMode = false
            state.isPiPActive = false
        }
    }

    func enableVideoPlayback() {
        state.isVideoMode = true
    }

    func disableVideoPlayback() {
        state.isVideoMode = false
        state.isPiPActive = false
    }

    // MARK: - Sleep Timer

    private var sleepTimerTask: Task<Void, Never>?

    func setSleepTimer(minutes: Int) {
        state.sleepTimerEnd = Date().addingTimeInterval(TimeInterval(minutes * 60))
        scheduleSleepTimer()
    }

    func cancelSleepTimer() {
        state.sleepTimerEnd = nil
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
    }

    private func scheduleSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = Task { @MainActor in
            guard let end = state.sleepTimerEnd else { return }
            let interval = end.timeIntervalSinceNow
            guard interval > 0 else { return }

            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }

            if state.sleepTimerEnd != nil {
                pause()
                state.sleepTimerEnd = nil
            }
        }
    }

    // MARK: - Time Observer

    private func setupTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = max(0, time.seconds)
            if abs(self.state.currentTime - current) >= 0.15 {
                self.state.currentTime = current
            }
            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite,
               abs(self.state.duration - duration) >= 0.25 {
                self.state.duration = duration
            }
        }
    }

    /// Seeks to the saved/explicit resume position once the player item can honor it.
    ///
    /// A previous implementation seeked after a fixed 350ms delay, but for streamed episodes the
    /// `AVPlayerItem` is usually not `.readyToPlay` that quickly, so the seek was dropped and playback
    /// restarted from 0. This waits for readiness via KVO (or seeks immediately if already ready) so the
    /// resume position reliably lands, without blocking the main thread or reintroducing a launch hang.
    private func scheduleStartupSeek(to time: TimeInterval, episodeID: String) {
        cancelStartupSeek()
        guard time > 0, let item = player?.currentItem else { return }

        // `cancelStartupSeek()` bumped the token to a fresh value held by nobody else; capture it so
        // the seek runs for this scheduling only.
        let token = startupSeekToken

        if item.status == .readyToPlay {
            performStartupSeek(to: time, episodeID: episodeID, token: token)
            return
        }

        startupSeekStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard observedItem.status == .readyToPlay else { return }
            Task { @MainActor [weak self] in
                guard let self,
                      token == self.startupSeekToken,
                      self.state.currentEpisode?.id == episodeID,
                      observedItem === self.player?.currentItem else { return }
                self.performStartupSeek(to: time, episodeID: episodeID, token: token)
            }
        }
    }

    private func performStartupSeek(to time: TimeInterval, episodeID: String, token: Int) {
        guard token == startupSeekToken else { return }
        // Consume the token and permanently tear down the readiness observer so the resume-seek can
        // run only once per session: a later `.readyToPlay` (after a rebuffer/stall/route change) — or
        // a duplicate readyToPlay KVO delivery — can never re-seek playback back to the start position.
        startupSeekToken &+= 1
        startupSeekStatusObservation?.invalidate()
        startupSeekStatusObservation = nil

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(
            to: cmTime,
            toleranceBefore: .zero,
            toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600)
        ) { [weak self] finished in
            guard finished, let self, self.state.currentEpisode?.id == episodeID else { return }
            self.state.currentTime = time
            self.updateNowPlayingInfo()
        }
    }

    private func cancelStartupSeek() {
        // Invalidate any pending resume-seek (token mismatch aborts in-flight observer Tasks too).
        startupSeekToken &+= 1
        startupSeekTask?.cancel()
        startupSeekTask = nil
        startupSeekStatusObservation?.invalidate()
        startupSeekStatusObservation = nil
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func observeTimeControlStatus() {
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self, self.state.isPlaying else { return }
                self.state.isBuffering = player.timeControlStatus != .playing
            }
        }
    }

    private func removePlaybackEndObserver() {
        if let o = endPlaybackObserver {
            NotificationCenter.default.removeObserver(o)
            endPlaybackObserver = nil
        }
    }

    private func removeAudioSessionInterruptionObserver() {
        if let o = audioInterruptionObserver {
            NotificationCenter.default.removeObserver(o)
            audioInterruptionObserver = nil
        }
    }

    private func observeAudioSessionInterruptions() {
        removeAudioSessionInterruptionObserver()
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification)
        }
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        switch type {
        case .began:
            shouldResumeAfterInterruption = state.isPlaying
            player?.pause()
            state.isPlaying = false
            updateNowPlayingInfo()
        case .ended:
            let optionsRaw = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
            let shouldResume = shouldResumeAfterInterruption && options.contains(.shouldResume)
            shouldResumeAfterInterruption = false

            if shouldResume {
                // `resume()` reactivates the audio session off the main thread before playing.
                resume()
            } else {
                activateAudioSessionForPlaybackDetached()
                state.isPlaying = false
                updateNowPlayingInfo()
            }
        @unknown default:
            break
        }
    }

    private func observePlaybackEnd(for item: AVPlayerItem) {
        removePlaybackEndObserver()
        endPlaybackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handlePlaybackDidFinish()
            }
        }
    }

    @MainActor
    private func handlePlaybackDidFinish() async {
        await markCurrentEpisodeFinished()
        guard !state.queue.isEmpty else {
            state.isPlaying = false
            updateNowPlayingInfo()
            return
        }
        await playNextInQueue()
    }

    // MARK: - Now Playing

    private func podcastForArtwork(episode: Episode) -> Podcast? {
        if let podcast = state.currentPodcast {
            if podcast.id == episode.podcastID { return podcast }
            if podcast.feedURL.absoluteString == episode.podcastID { return podcast }
        }
        return Podcast.loadFollowedPodcasts().first { p in
            p.id == episode.podcastID || p.feedURL.absoluteString == episode.podcastID
        }
    }

    private func resolvedArtworkURL(for episode: Episode) -> URL? {
        episode.resolvedArtworkURL(podcast: podcastForArtwork(episode: episode))
    }

    private func updateNowPlayingInfo() {
        guard let episode = state.currentEpisode else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = episode.title
        info[MPMediaItemPropertyArtist] = state.currentPodcast?.title ?? podcastForArtwork(episode: episode)?.title ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? state.playbackRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let artworkURL = resolvedArtworkURL(for: episode)
        let artworkKey = "\(episode.id)|\(artworkURL?.absoluteString ?? "")"
        guard artworkKey != lastNowPlayingArtworkKey else { return }
        lastNowPlayingArtworkKey = artworkKey
        scheduleNowPlayingArtworkFetch(episodeID: episode.id, url: artworkURL)
    }

    private func scheduleNowPlayingArtworkFetch(episodeID: String, url: URL?) {
        nowPlayingArtworkTask?.cancel()
        guard let url else {
            Task { @MainActor in
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info.removeValue(forKey: MPMediaItemPropertyArtwork)
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
            return
        }

        nowPlayingArtworkTask = Task { [weak self] in
            guard let self else { return }
            await ImageCache.shared.prefetchImage(from: url)
            guard let image = await ImageCache.shared.getImageAsync(for: url) else { return }
            guard !Task.isCancelled else { return }
            let mediaArtwork = Self.makeNowPlayingArtwork(from: image)
            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard self.state.currentEpisode?.id == episodeID else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = mediaArtwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    private static func makeNowPlayingArtwork(from image: UIImage) -> MPMediaItemArtwork {
        let bounds = image.size
        return MPMediaItemArtwork(boundsSize: bounds) { requestedSize in
            guard requestedSize.width > 0, requestedSize.height > 0 else { return image }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 0
            let renderer = UIGraphicsImageRenderer(size: requestedSize, format: format)
            return renderer.image { _ in
                let scale = max(
                    requestedSize.width / image.size.width,
                    requestedSize.height / image.size.height
                )
                let w = image.size.width * scale
                let h = image.size.height * scale
                let rect = CGRect(
                    x: (requestedSize.width - w) / 2,
                    y: (requestedSize.height - h) / 2,
                    width: w,
                    height: h
                )
                image.draw(in: rect)
            }
        }
    }

    // MARK: - Remote Commands

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }

        center.pauseCommand.removeTarget(nil)
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        center.togglePlayPauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        center.skipForwardCommand.removeTarget(nil)
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        center.skipBackwardCommand.removeTarget(nil)
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }

        center.changePlaybackPositionCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    // MARK: - Position Saving

    private func startPositionSaving() {
        positionSaveTask?.cancel()
        positionSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                await persistPlaybackProgress()
            }
        }
    }

    private func persistPlaybackProgress() async {
        guard var episode = state.currentEpisode else { return }
        let policy = PlaybackProgressPolicy.current
        let dur = policy.effectiveDuration(feedDuration: episode.duration, observedDuration: state.duration)
        let position = state.currentTime
        if dur > 0 {
            EpisodePlaybackStore.recordLastPlayedEpisode(episodeID: episode.id, podcastID: episode.podcastID)
            EpisodePlaybackStore.saveProgress(
                episodeID: episode.id,
                position: position,
                duration: dur,
                policy: policy
            )
            if policy.isFinished(playbackPosition: position, duration: dur) {
                episode.isPlayed = true
            }
            recordListeningHistory(episode: episode, position: position, duration: dur)
        } else if position > 0 {
            EpisodePlaybackStore.recordLastPlayedEpisode(episodeID: episode.id, podcastID: episode.podcastID)
            EpisodePlaybackStore.persistPosition(position, episodeID: episode.id, notify: true)
            recordListeningHistory(episode: episode, position: position, duration: episode.duration)
        } else {
            await MainActor.run { persistResumeSessionArchiveFromCurrentState() }
            return
        }
        episode.playbackPosition = position
        state.currentEpisode = episode
        await MainActor.run { persistResumeSessionArchiveFromCurrentState() }
    }

    private func markCurrentEpisodeFinished() async {
        guard var episode = state.currentEpisode else { return }
        let policy = PlaybackProgressPolicy.current
        let dur = policy.effectiveDuration(feedDuration: episode.duration, observedDuration: state.duration)
        let position = dur > 0 ? dur : state.currentTime
        if dur > 0 {
            EpisodePlaybackStore.recordLastPlayedEpisode(episodeID: episode.id, podcastID: episode.podcastID)
            EpisodePlaybackStore.saveProgress(
                episodeID: episode.id,
                position: position,
                duration: dur,
                policy: policy
            )
        } else {
            EpisodePlaybackStore.recordLastPlayedEpisode(episodeID: episode.id, podcastID: episode.podcastID)
            EpisodePlaybackStore.persistPosition(position, episodeID: episode.id, notify: false)
        }
        EpisodePlaybackStore.persistPlayed(true, episodeID: episode.id, notify: false)
        NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episode.id)
        episode.playbackPosition = position
        episode.isPlayed = true
        state.currentEpisode = episode
        updateNowPlayingInfo()
        recordListeningHistory(episode: episode, position: position, duration: dur > 0 ? dur : episode.duration)
        await MainActor.run {
            persistResumeSessionArchiveFromCurrentState()
        }
    }

    private func recordListeningHistory(episode: Episode, position: TimeInterval, duration: TimeInterval) {
        let merged = EpisodePlaybackStore.merge(episode)
        var snapshot = merged
        snapshot.playbackPosition = position
        if duration > 0, PlaybackProgressPolicy.current.isFinished(playbackPosition: position, duration: duration) {
            snapshot.isPlayed = true
        }
        ListeningHistoryStore.recordListening(
            episode: snapshot,
            podcast: state.currentPodcast,
            position: position,
            duration: duration > 0 ? duration : merged.duration
        )
    }
}
