import Foundation
import AVFoundation
import MediaPlayer
import Observation

@Observable
class PlaybackService {
    static let shared = PlaybackService()

    let state = PlaybackState()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var positionSaveTask: Task<Void, Never>?

    init() {}

    // MARK: - Core Playback

    func play(episode: Episode, podcast: Podcast? = nil, startAt: TimeInterval? = nil) async {
        let url = episode.downloadedFileURL ?? episode.audioURL

        let playerItem = AVPlayerItem(url: url)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        state.currentEpisode = episode
        state.currentPodcast = podcast
        state.isPlaying = true
        state.currentTime = startAt ?? episode.playbackPosition
        state.duration = episode.duration
        state.isBuffering = true

        if let startTime = startAt ?? (episode.playbackPosition > 0 ? episode.playbackPosition : nil) {
            await player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        }

        player?.rate = state.playbackRate
        setupTimeObserver()
        updateNowPlayingInfo()
        configureRemoteCommands()
        startPositionSaving()

        state.isBuffering = false
    }

    func pause() {
        player?.pause()
        state.isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        player?.play()
        player?.rate = state.playbackRate
        state.isPlaying = true
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
        player?.seek(to: cmTime) { [weak self] _ in
            self?.state.currentTime = time
            self?.updateNowPlayingInfo()
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
        if state.isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        removeTimeObserver()
        state.currentEpisode = nil
        state.currentPodcast = nil
        state.isPlaying = false
        state.currentTime = 0
        state.duration = 0
        positionSaveTask?.cancel()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Queue Management

    func addToQueue(_ episode: Episode) {
        if !state.queue.contains(where: { $0.id == episode.id }) {
            state.queue.append(episode)
        }
    }

    func removeFromQueue(_ episode: Episode) {
        state.queue.removeAll { $0.id == episode.id }
    }

    func playNext(_ episode: Episode) {
        removeFromQueue(episode)
        state.queue.insert(episode, at: 0)
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
        await play(episode: next)
    }

    // MARK: - Video

    func enableVideoPlayback() {
        state.isVideoMode = true
    }

    func disableVideoPlayback() {
        state.isVideoMode = false
        state.isPiPActive = false
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) {
        state.sleepTimerEnd = Date().addingTimeInterval(TimeInterval(minutes * 60))
        scheduleSleepTimer()
    }

    func cancelSleepTimer() {
        state.sleepTimerEnd = nil
    }

    private func scheduleSleepTimer() {
        Task { @MainActor in
            guard let end = state.sleepTimerEnd else { return }
            let interval = end.timeIntervalSinceNow
            guard interval > 0 else { return }

            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

            if state.sleepTimerEnd != nil {
                pause()
                state.sleepTimerEnd = nil
            }
        }
    }

    // MARK: - Time Observer

    private func setupTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.state.currentTime = time.seconds
            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                self.state.duration = duration
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    // MARK: - Now Playing

    private func updateNowPlayingInfo() {
        guard let episode = state.currentEpisode else { return }

        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = episode.title
        info[MPMediaItemPropertyArtist] = state.currentPodcast?.title ?? ""
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? state.playbackRate : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
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
                await savePlaybackPosition()
            }
        }
    }

    private func savePlaybackPosition() async {
        guard var episode = state.currentEpisode else { return }
        episode.playbackPosition = state.currentTime
        UserDefaults.standard.set(state.currentTime, forKey: "position_\(episode.id)")
        NSUbiquitousKeyValueStore.default.set(state.currentTime, forKey: "position_\(episode.id)")
    }
}
