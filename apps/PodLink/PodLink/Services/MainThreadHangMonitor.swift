#if DEBUG
import Foundation
import os

/// Debug-only watchdog that flags main-thread hangs.
///
/// A background queue pings the main queue on a fixed cadence and measures how long the ping
/// takes to run. When that latency crosses `threshold`, the main thread was blocked for that
/// long, and it logs the duration via `os.Logger` (subsystem `PodLink`, category `HangMonitor`).
///
/// To capture *where* a hang happens: open Console (or Xcode's debug console), reproduce the
/// stall, note the logged duration/timestamp, then run Instruments → Time Profiler (or the Hangs
/// template) and look at the main thread around that timestamp. The log tells you when to look.
final class MainThreadHangMonitor: @unchecked Sendable {
    static let shared = MainThreadHangMonitor()

    private let logger = Logger(subsystem: "PodLink", category: "HangMonitor")
    private let queue = DispatchQueue(label: "PodLink.HangMonitor", qos: .utility)
    private let threshold: TimeInterval
    private let pollInterval: TimeInterval
    private var started = false

    private init(threshold: TimeInterval = 0.25, pollInterval: TimeInterval = 0.05) {
        self.threshold = threshold
        self.pollInterval = pollInterval
    }

    func start() {
        queue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            self.scheduleProbe()
        }
    }

    private func scheduleProbe() {
        queue.asyncAfter(deadline: .now() + pollInterval) { [weak self] in
            self?.probe()
        }
    }

    private func probe() {
        let start = DispatchTime.now()
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + 30.0)

        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
        if elapsed >= threshold {
            logger.warning("⚠️ Main thread hang: \(elapsed, format: .fixed(precision: 3))s (threshold \(self.threshold, format: .fixed(precision: 2))s)")
        }
        scheduleProbe()
    }
}
#endif
