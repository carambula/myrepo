import Foundation

/// Runs on-device transcription jobs in the background, independent of any view lifecycle.
/// A single job per episode is guaranteed — subsequent calls are ignored while one is running.
@MainActor
@Observable
final class BackgroundTranscriptionManager {
    static let shared = BackgroundTranscriptionManager()

    private(set) var jobs: [String: Job] = [:]

    struct Job {
        enum Status { case running, completed, failed }
        var status: Status
        var progress: String?
        var errorMessage: String?
    }

    // MARK: - Queries

    func isRunning(for episodeID: String) -> Bool {
        jobs[episodeID]?.status == .running
    }

    func progress(for episodeID: String) -> String? {
        jobs[episodeID]?.progress
    }

    func error(for episodeID: String) -> String? {
        jobs[episodeID]?.errorMessage
    }

    func clearError(for episodeID: String) {
        jobs[episodeID]?.errorMessage = nil
    }

    // MARK: - Control

    /// Starts on-device transcription. No-op if a job for this episode is already running.
    func transcribe(episode: Episode) {
        guard jobs[episode.id]?.status != .running else { return }
        jobs[episode.id] = Job(status: .running, progress: "Preparing audio…")
        let episodeID = episode.id
        Task.detached(priority: .utility) {
            do {
                _ = try await TranscriptService.shared.requestOnDeviceTranscript(
                    for: episode
                ) { progress in
                    Task { @MainActor in
                        BackgroundTranscriptionManager.shared.updateProgress(episodeID: episodeID,
                                                                             progress: progress)
                    }
                }
                await MainActor.run {
                    BackgroundTranscriptionManager.shared.markCompleted(episodeID: episodeID)
                }
            } catch {
                let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run {
                    BackgroundTranscriptionManager.shared.markFailed(episodeID: episodeID,
                                                                      errorMessage: msg)
                }
            }
        }
    }

    /// Clears caches and restarts transcription from scratch.
    func retranscribe(episode: Episode) {
        guard jobs[episode.id]?.status != .running else { return }
        let episodeID = episode.id
        Task {
            await TranscriptService.shared.clearTranscriptCache(for: episode)
            await TranscriptAnalysisService.shared.invalidate(for: episodeID)
            await OnDeviceTranscriptionService.shared.clearCheckpoint(for: episodeID)
            jobs[episodeID] = nil
            transcribe(episode: episode)
        }
    }

    // MARK: - Internal state updates (called from detached tasks)

    func updateProgress(episodeID: String, progress: String) {
        guard jobs[episodeID]?.status == .running else { return }
        jobs[episodeID]?.progress = progress
    }

    func markCompleted(episodeID: String) {
        jobs[episodeID]?.status = .completed
        jobs[episodeID]?.progress = nil
    }

    func markFailed(episodeID: String, errorMessage: String) {
        jobs[episodeID]?.status = .failed
        jobs[episodeID]?.progress = nil
        jobs[episodeID]?.errorMessage = errorMessage
    }
}
