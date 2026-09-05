#if os(iOS)
import CoreMotion
import Foundation

/// Detects a quick side-to-side phone shake (about two back-and-forths)
/// and fires registered handlers. Uses device-motion user acceleration
/// so gravity is filtered out.
@MainActor
public final class RageShakeDetector {
    public static let shared = RageShakeDetector()

    /// Lateral peak magnitude (g, user acceleration) to count as one impulse.
    public var threshold: Double = 1.85
    /// Direction reversals that count as a rage shake (2 back-and-forths ≈ 4 peaks).
    public var requiredPeaks: Int = 4
    /// Window in which those peaks must arrive.
    public var windowSeconds: TimeInterval = 1.15
    /// Ignore further shakes after a trigger.
    public var cooldownSeconds: TimeInterval = 2.5

    private let motion = CMMotionManager()
    private var lastSign: Int = 0
    private var peakTimes: [TimeInterval] = []
    private var lastFire: TimeInterval = 0
    private var handlers: [UUID: () -> Void] = [:]
    private var started = false

    public init() {}

    /// Register a handler. Returns an id to pass to `remove`.
    @discardableResult
    public func addHandler(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        handlers[id] = handler
        startIfNeeded()
        return id
    }

    public func remove(_ id: UUID) {
        handlers.removeValue(forKey: id)
        if handlers.isEmpty {
            stop()
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        if motion.isDeviceMotionAvailable {
            started = true
            motion.deviceMotionUpdateInterval = 1.0 / 50.0
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.process(
                    x: data.userAcceleration.x,
                    y: data.userAcceleration.y,
                    timestamp: data.timestamp
                )
            }
            return
        }
        guard motion.isAccelerometerAvailable else { return }
        started = true
        motion.accelerometerUpdateInterval = 1.0 / 50.0
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            // Raw accelerometer includes gravity; use a higher bar.
            self.process(
                x: data.acceleration.x,
                y: data.acceleration.y,
                timestamp: data.timestamp,
                rawThreshold: 2.4
            )
        }
    }

    private func stop() {
        guard started else { return }
        motion.stopDeviceMotionUpdates()
        motion.stopAccelerometerUpdates()
        started = false
        lastSign = 0
        peakTimes.removeAll()
    }

    private func process(x: Double, y: Double, timestamp: TimeInterval, rawThreshold: Double? = nil) {
        let bar = rawThreshold ?? threshold
        // Side-to-side in portrait is X; in landscape often Y.
        let lateral = abs(x) >= abs(y) ? x : y
        guard abs(lateral) >= bar else { return }

        let sign = lateral >= 0 ? 1 : -1
        if sign == lastSign { return }
        lastSign = sign

        peakTimes.append(timestamp)
        peakTimes = peakTimes.filter { timestamp - $0 <= windowSeconds }

        guard peakTimes.count >= requiredPeaks else { return }
        guard timestamp - lastFire >= cooldownSeconds else { return }

        lastFire = timestamp
        peakTimes.removeAll()
        lastSign = 0
        for callback in handlers.values {
            callback()
        }
    }
}

#else

import Foundation

@MainActor
public final class RageShakeDetector {
    public static let shared = RageShakeDetector()
    public init() {}
    @discardableResult
    public func addHandler(_ handler: @escaping () -> Void) -> UUID { UUID() }
    public func remove(_ id: UUID) {}
}

#endif
