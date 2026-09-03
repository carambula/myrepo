import UIKit
import CoreText

/// Registers individual bundled Rotina `.woff2` weights with Core Text, on demand, off the main thread.
///
/// History / why this is shaped the way it is:
/// - The Rotina weights used to be declared in `Info.plist` `UIAppFonts`, which made the system load,
///   brotli-decompress, and register all 16 `.woff2` files synchronously on the main thread at launch.
/// - Moving that to a launch-time background pass still hurt: registering 16 woff2 files holds the Core
///   Text font-registry lock while the main thread does first layout, so the main thread stalled for
///   seconds, and every weight shares the same copyright metadata so Core Graphics logged
///   `GSFont: "...licensed for web use only." already exists.` ~15 times.
///
/// The Rotina fonts are only ever rendered by the Font Settings preview, so registration is now fully
/// lazy: callers register just the specific weights they are about to display, each at most once, on a
/// background queue. A default cold start does no font work at all.
enum RotinaFontRegistrar {
    nonisolated private static let queue = DispatchQueue(label: "PodLink.RotinaFontRegistrar", qos: .userInitiated)
    nonisolated private static let lock = NSLock()
    /// Base names (e.g. "Rotina-Bold") already registered (or scheduled). Guarded by `lock`.
    nonisolated(unsafe) private static var registeredNames: Set<String> = []

    /// Registers the given Rotina weight files (base names without extension, e.g. "Rotina-Bold").
    ///
    /// Each name is registered at most once per process. Work runs on a background queue. `onNewlyRegistered`
    /// runs on the main actor only when at least one new font was registered (so callers can refresh the UI
    /// without risking a re-render loop when everything is already registered).
    nonisolated static func ensureRegistered(
        fontNames: [String],
        onNewlyRegistered: (@MainActor @Sendable () -> Void)? = nil
    ) {
        lock.lock()
        let pending = fontNames.filter { !registeredNames.contains($0) }
        for name in pending { registeredNames.insert(name) }
        lock.unlock()

        guard !pending.isEmpty else { return }

        queue.async {
            for name in pending {
                guard let url = fontURL(named: name) else { continue }
                var errorRef: Unmanaged<CFError>?
                if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef) {
                    errorRef?.release()
                }
            }
            if let onNewlyRegistered { Task { @MainActor in onNewlyRegistered() } }
        }
    }

    private nonisolated static func fontURL(named name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "woff2") {
            return url
        }
        // Fall back to the source subdirectory in case resources are not flattened to the bundle root.
        return Bundle.main.url(forResource: name, withExtension: "woff2", subdirectory: "Fonts/Rotina")
    }
}
