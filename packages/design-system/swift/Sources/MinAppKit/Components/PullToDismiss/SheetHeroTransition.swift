import Observation
import os
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Shared motion for zooming a sheet out of a matching key image.
public enum SheetHeroMotion {
    /// Open zoom, close zoom, and scrim fade — one shared duration so
    /// stacked layers, the flying image, and shade move together.
    public static let openDuration: TimeInterval = 0.42
}

/// Debug-build trace of how a hero sheet was classified and handled. Filter
/// the Xcode console on `SheetHero` to see one presentation end to end.
enum SheetHeroDiagnostics {
    #if DEBUG
    private static let logger = Logger(subsystem: "MinAppKit", category: "SheetHero")
    #endif

    static func log(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }
}

/// Stable ids for a source image and the sheet it opens. The two must match.
public enum SheetHeroID {
    public static func podcast(_ id: String) -> String { "podcast:\(id)" }
    public static func episode(_ id: String) -> String { "episode:\(id)" }
    /// Mini-player artwork ↔ now-playing sheet. Distinct from `episode` so
    /// list/grid thumbs of the same episode are never the zoom source or cover target.
    public static func miniPlayer(_ id: String) -> String { "miniPlayer:\(id)" }
    public static func movie(_ id: String) -> String { "movie:\(id)" }
    public static func video(_ id: String) -> String { "video:\(id)" }
    public static func channel(_ id: String) -> String { "channel:\(id)" }

    /// Mini-player artwork in a secondary overlay window. Live art stays
    /// hidden; a matched idle copy is the visible thumb, and cover opacity
    /// hides that copy while the matching sheet is the foreground object.
    public static func isMiniPlayer(_ id: String) -> Bool {
        id.hasPrefix("miniPlayer:")
    }
}

/// Last frames, radii, and snapshots of hero sources, used to fling a sheet
/// back into the thumbnail when the system zoom transition is not driving
/// dismiss. Off-screen sources keep their last frame and image so the
/// returning card can still land and fill with the key art.
@MainActor
public enum SheetHeroGeometry {
    private static var frames: [String: CGRect] = [:]
    private static var radii: [String: CGFloat] = [:]
    private static var onScreenIDs: Set<String> = []
    #if os(iOS)
    private static var images: [String: UIImage] = [:]
    #endif
    private static var namespaceStack: [Namespace.ID] = []
    private static var presentedSheetCount = 0

    public static func update(id: String, frame: CGRect, cornerRadius: CGFloat, onScreen: Bool) {
        if SheetHeroSession.shared.isCovered(id) { return }
        guard EdgeSwipeToDismiss.shouldReplaceHeroFrame(
            existing: frames[id],
            next: frame,
            existingOnScreen: onScreenIDs.contains(id),
            nextOnScreen: onScreen
        ) else { return }
        frames[id] = frame
        radii[id] = cornerRadius
        if onScreen {
            onScreenIDs.insert(id)
        } else {
            onScreenIDs.remove(id)
        }
    }

    public static func frame(for id: String) -> CGRect? {
        frames[id]
    }

    public static func cornerRadius(for id: String) -> CGFloat {
        radii[id] ?? MinCornerRadius.artTile
    }

    public static func isOnScreen(_ id: String) -> Bool {
        onScreenIDs.contains(id)
    }

    public static func setOnScreen(_ id: String, _ onScreen: Bool) {
        if onScreen {
            onScreenIDs.insert(id)
        } else {
            onScreenIDs.remove(id)
        }
    }

    #if os(iOS)
    public static func setImage(_ image: UIImage?, for id: String) {
        guard let image, image.size.width > 8, image.size.height > 8 else { return }
        images[id] = image
    }

    public static func image(for id: String) -> UIImage? {
        images[id]
    }
    #endif

    /// True when a sheet (or full-screen cover) is already presented, so a
    /// sheet opened from it must not zoom — only the root sheet over home.
    static var isInsidePresentedSheet: Bool {
        presentedSheetCount > 0
    }

    static func enterPresentedSheet() {
        presentedSheetCount += 1
    }

    static func leavePresentedSheet() {
        presentedSheetCount = max(0, presentedSheetCount - 1)
    }

    static var currentNamespace: Namespace.ID? {
        namespaceStack.last
    }

    /// Register a container namespace. A parent that is already on the stack
    /// stays put so its body refreshes cannot steal the top from a nested
    /// search or show sheet that is currently presenting.
    static func activate(_ namespace: Namespace.ID) {
        if namespaceStack.contains(where: { $0 == namespace }) { return }
        namespaceStack.append(namespace)
    }

    static func pushNamespace(_ namespace: Namespace.ID) {
        activate(namespace)
    }

    static func popNamespace(_ namespace: Namespace.ID) {
        if let index = namespaceStack.lastIndex(of: namespace) {
            namespaceStack.remove(at: index)
        }
    }
}

/// Hides the real tile while its matching sheet is the flying object so the
/// morph is one picture, not a copy over a still-visible thumbnail.
@MainActor
@Observable
final class SheetHeroSession {
    static let shared = SheetHeroSession()

    private(set) var coveredIDs: Set<String> = []
    private var dismissHandlers: [() -> Void] = []

    // Zoom bookkeeping is written while SwiftUI builds views and read by
    // UIKit guards, always on the main thread. It stays out of observation
    // and, like `isHeroMotionActive`, out of MainActor isolation.
    nonisolated(unsafe) private static var activeZoomIDs: [String: Int] = [:]
    nonisolated(unsafe) private static var zoomExpectedUntil: TimeInterval = 0

    /// True from the moment a zoom sheet is about to be presented until its
    /// destination is torn down. Presenting-side guards read this when UIKit
    /// reports the new sheet, which is before the sheet has rendered.
    nonisolated static var usesSystemZoom: Bool {
        !activeZoomIDs.isEmpty
            || ProcessInfo.processInfo.systemUptime < zoomExpectedUntil
    }

    /// Call while building the presented content, before UIKit presents it.
    /// Waiting for the destination to render is too late: by then the
    /// presenting-side scrim may already have rewritten the sheet's chrome.
    nonisolated static func expectZoomPresentation(_ id: String) {
        guard activeZoomIDs[id] == nil else { return }
        if !usesSystemZoom {
            SheetHeroDiagnostics.log("expect zoom \(id)")
        }
        // Normally the sheet renders within one run-loop turn. The window
        // only bounds a presentation that never happens.
        zoomExpectedUntil = ProcessInfo.processInfo.systemUptime + 1
    }

    nonisolated static func enterZoomDestination(_ id: String) {
        activeZoomIDs[id, default: 0] += 1
        zoomExpectedUntil = 0
        SheetHeroDiagnostics.log("zoom destination rendered \(id)")
    }

    nonisolated static func leaveZoomDestination(_ id: String) {
        guard let count = activeZoomIDs[id] else { return }
        activeZoomIDs[id] = count > 1 ? count - 1 : nil
        SheetHeroDiagnostics.log("zoom destination removed \(id)")
    }

    /// True while `id`'s zoom destination is still in the hierarchy.
    nonisolated static func isActiveZoomDestination(_ id: String) -> Bool {
        activeZoomIDs[id] != nil
    }

    /// True while a proxy is following the finger or flying back to a tile.
    /// Radius guards must not rewrite `preferredCornerRadius` in this window.
    /// `nonisolated(unsafe)` so UIKit display-link / dimming callbacks can
    /// read it without hopping through a MainActor autoclosure.
    nonisolated(unsafe) static var isHeroMotionActive = false

    func cover(_ id: String?) {
        guard let id, !id.isEmpty else { return }
        coveredIDs.insert(id)
    }

    func uncover(_ id: String?) {
        guard let id else { return }
        coveredIDs.remove(id)
    }

    func isCovered(_ id: String) -> Bool {
        coveredIDs.contains(id)
    }

    /// Edge-swipe hosts push a handler so close / pull-to-dismiss can fling
    /// through the same motion (including off-screen image fill) instead of
    /// the system zoom, which breaks when the source cell is gone.
    func pushDismissHandler(_ handler: @escaping () -> Void) {
        dismissHandlers.append(handler)
    }

    func popDismissHandler() {
        if !dismissHandlers.isEmpty {
            dismissHandlers.removeLast()
        }
    }

    @discardableResult
    func requestInteractiveDismiss() -> Bool {
        guard let handler = dismissHandlers.last else { return false }
        handler()
        return true
    }
}

private struct SheetHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct SheetHeroPresentedIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct SheetHeroAllowsZoomKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Shared zoom namespace for a source image and the sheet it opens.
    /// Presented sheet content should re-apply this; SwiftUI does not always
    /// carry custom environment values across `.sheet` / `.fullScreenCover`.
    public var sheetHeroNamespace: Namespace.ID? {
        get { self[SheetHeroNamespaceKey.self] }
        set { self[SheetHeroNamespaceKey.self] = newValue }
    }

    var sheetHeroPresentedID: String? {
        get { self[SheetHeroPresentedIDKey.self] }
        set { self[SheetHeroPresentedIDKey.self] = newValue }
    }

    /// Source images may morph into a presented sheet via the system zoom.
    public var sheetHeroAllowsZoom: Bool {
        get { self[SheetHeroAllowsZoomKey.self] }
        set { self[SheetHeroAllowsZoomKey.self] = newValue }
    }
}

private struct SheetHeroContainerModifier: ViewModifier {
    var participatesInGlobalStack: Bool = true
    @Namespace private var namespace

    func body(content: Content) -> some View {
        if participatesInGlobalStack {
            SheetHeroGeometry.activate(namespace)
        }
        return content
            .environment(\.sheetHeroNamespace, namespace)
            .onAppear {
                if participatesInGlobalStack {
                    SheetHeroGeometry.pushNamespace(namespace)
                }
            }
            .onDisappear {
                if participatesInGlobalStack {
                    SheetHeroGeometry.popNamespace(namespace)
                }
            }
            #if os(iOS)
            .background(
                SheetScrimGuard()
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            )
            #endif
    }
}

#if os(iOS)
private func sheetHeroFrameIsOnScreen(_ frame: CGRect) -> Bool {
    let screen = UIScreen.main.bounds
    let visible = screen.intersection(frame)
    return visible.width > 8 && visible.height > 8
}
#endif

private struct SheetHeroSourceModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var environmentNamespace
    @Environment(\.sheetHeroAllowsZoom) private var allowsZoom
    let id: String
    let cornerRadius: CGFloat

    private var namespace: Namespace.ID? {
        environmentNamespace ?? SheetHeroGeometry.currentNamespace
    }

    func body(content: Content) -> some View {
        let sourced = content
            .background {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear
                        .onAppear { record(frame) }
                        .onChange(of: frame) { _, newFrame in
                            record(newFrame)
                        }
                        .onDisappear {
                            SheetHeroGeometry.setOnScreen(id, false)
                        }
                        #if os(iOS)
                        .overlay {
                            SheetHeroImageCapture(id: id)
                                .frame(width: 0, height: 0)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        #endif
                }
            }

        #if os(iOS)
        // App Store-style zoom: the system morphs this image into the sheet.
        // Grid/list tiles must stay live — a second copy reads as a leftover
        // thumb. Mini-player art lives in an overlay window where
        // `matchedTransitionSource` hides the live view even when idle, so
        // that source keeps a hit-test-free copy as the only visible art.
        if allowsZoom, let namespace {
            if #available(iOS 18.0, *) {
                if SheetHeroID.isMiniPlayer(id) {
                    // Live art stays invisible — uncovering the matched copy at
                    // dismiss start (opaque land target) must not also reveal a
                    // second thumb in the microplayer during the return flight.
                    // Cover opacity only gates that matched copy: hidden while
                    // the sheet is settled, opaque for the return morph.
                    sourced
                        .opacity(0)
                        .accessibilityHidden(true)
                        .overlay {
                            content
                                .matchedTransitionSource(id: id, in: namespace) { source in
                                    source.clipShape(
                                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    )
                                }
                                .modifier(SheetHeroCoverOpacity(id: id))
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                } else {
                    sourced
                        .matchedTransitionSource(id: id, in: namespace) { source in
                            source.clipShape(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            )
                        }
                }
            } else {
                sourced
            }
        } else {
            sourced
        }
        #else
        sourced
        #endif
    }

    private func record(_ frame: CGRect) {
        #if os(iOS)
        let onScreen = sheetHeroFrameIsOnScreen(frame)
        #else
        let onScreen = true
        #endif
        SheetHeroGeometry.update(
            id: id,
            frame: frame,
            cornerRadius: cornerRadius,
            onScreen: onScreen
        )
    }
}

#if os(iOS)
/// Walks the source tile for a UIImage so dismiss can fade that art into the
/// returning card when the live thumbnail has scrolled off-screen.
private struct SheetHeroImageCapture: UIViewRepresentable {
    let id: String

    func makeUIView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.heroID = id
        return view
    }

    func updateUIView(_ uiView: CaptureView, context: Context) {
        uiView.heroID = id
        uiView.captureSoon()
    }

    final class CaptureView: UIView {
        var heroID: String = ""
        private var pending: DispatchWorkItem?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            backgroundColor = .clear
        }

        @available(*, unavailable) required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            captureSoon()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            captureSoon()
        }

        func captureSoon() {
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.capture()
            }
            pending = work
            DispatchQueue.main.async(execute: work)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: DispatchWorkItem { [weak self] in
                self?.capture()
            })
        }

        private func capture() {
            guard !heroID.isEmpty else { return }
            if SheetHeroGeometry.image(for: heroID) != nil { return }
            var node: UIView? = superview
            var hops = 0
            while let view = node, hops < 8 {
                if let image = firstImage(in: view) {
                    SheetHeroGeometry.setImage(image, for: heroID)
                    return
                }
                node = view.superview
                hops += 1
            }
        }

        private func firstImage(in root: UIView) -> UIImage? {
            var stack = [root]
            var visited = 0
            while let view = stack.popLast(), visited < 48 {
                visited += 1
                if let imageView = view as? UIImageView,
                   let image = imageView.image,
                   image.size.width > 8,
                   image.size.height > 8 {
                    return image
                }
                stack.append(contentsOf: view.subviews)
            }
            return nil
        }
    }
}
#endif

#if os(iOS)
/// Hides mini-player source art while its sheet owns the foreground so the
/// morph is one picture — not a leftover thumb under / behind the player.
private struct SheetHeroCoverOpacity: ViewModifier {
    let id: String
    var session = SheetHeroSession.shared

    func body(content: Content) -> some View {
        content
            .opacity(session.isCovered(id) ? 0 : 1)
            .transaction { $0.animation = nil }
    }
}

/// Holds the zoom session open for as long as the destination's hosting view
/// exists. `expectZoomPresentation` covers the gap before this view is made.
private struct SheetHeroZoomSessionProbe: UIViewRepresentable {
    let id: String

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.enter(id)
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.enter(id)
    }

    static func dismantleUIView(_ uiView: ProbeView, coordinator: ()) {
        uiView.leave()
    }

    final class ProbeView: UIView {
        private var activeID: String?

        func enter(_ id: String) {
            guard activeID != id else { return }
            leave()
            activeID = id
            SheetHeroSession.enterZoomDestination(id)
        }

        func leave() {
            guard let id = activeID else { return }
            activeID = nil
            SheetHeroSession.leaveZoomDestination(id)
        }
    }
}

/// Covers mini-player source art after open settles, and uncovers at dismiss
/// *start* so return zoom matches grid/list (opaque land, no fade-out).
private struct SheetHeroMiniCoverProbe: UIViewControllerRepresentable {
    let id: String

    func makeUIViewController(context: Context) -> CoverProbeController {
        let controller = CoverProbeController()
        controller.heroID = id
        return controller
    }

    func updateUIViewController(_ controller: CoverProbeController, context: Context) {
        controller.heroID = id
    }

    static func dismantleUIViewController(_ controller: CoverProbeController, coordinator: ()) {
        controller.cancelPendingCover()
        SheetHeroSession.shared.uncover(controller.heroID)
    }

    final class CoverProbeController: UIViewController {
        var heroID: String = ""
        private var coverWork: DispatchWorkItem?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            scheduleCoverIfNeeded()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            cancelPendingCover()
            // Dismiss commit — reveal the thumb before the return morph runs.
            // Waiting until tear-down kept opacity at 0 for the whole land and
            // looked like the art fading out on the way back.
            guard sheetHostIsBeingDismissed() else { return }
            SheetHeroSession.shared.uncover(heroID)
            SheetHeroDiagnostics.log("uncover mini source for dismiss \(heroID)")
        }

        /// This probe is a child of the sheet host; `isBeingDismissed` is often
        /// only set on the presented host, not on representable children.
        private func sheetHostIsBeingDismissed() -> Bool {
            var current: UIViewController? = self
            while let vc = current {
                if vc.presentingViewController != nil {
                    return vc.isBeingDismissed
                }
                if vc.isBeingDismissed { return true }
                current = vc.parent
            }
            return false
        }

        func scheduleCoverIfNeeded() {
            guard SheetHeroID.isMiniPlayer(heroID) else { return }
            cancelPendingCover()
            let coverID = heroID
            let work = DispatchWorkItem {
                guard SheetHeroSession.isActiveZoomDestination(coverID) else { return }
                SheetHeroSession.shared.cover(coverID)
                SheetHeroDiagnostics.log("cover mini source \(coverID)")
            }
            coverWork = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + SheetHeroMotion.openDuration,
                execute: work
            )
        }

        func cancelPendingCover() {
            coverWork?.cancel()
            coverWork = nil
        }
    }
}
#endif

private struct SheetHeroDestinationModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var environmentNamespace
    let id: String
    var explicitNamespace: Namespace.ID? = nil

    private var namespace: Namespace.ID? {
        explicitNamespace ?? environmentNamespace ?? SheetHeroGeometry.currentNamespace
    }

    func body(content: Content) -> some View {
        let tagged = content
            .environment(\.sheetHeroPresentedID, id)
            .environment(\.sheetHeroNamespace, namespace)
            .environment(\.sheetHeroAllowsZoom, true)
        #if os(iOS)
        // Nothing here may change the source or the sheet once the zoom has
        // started; the system owns both until the card lands. Mini-player
        // thumbs are covered only after the open spring settles, then
        // uncovered as soon as dismiss begins so return matches tiles.
        applyZoom(
            tagged
                .background {
                    SheetHeroZoomSessionProbe(id: id)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                }
                .background {
                    if SheetHeroID.isMiniPlayer(id) {
                        SheetHeroMiniCoverProbe(id: id)
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
                .onDisappear {
                    SheetHeroSession.shared.uncover(id)
                }
        )
        #else
        tagged
        #endif
    }

    @ViewBuilder
    private func applyZoom<V: View>(_ view: V) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), let namespace {
            view.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            view
        }
        #else
        view
        #endif
    }
}

private struct SheetHeroPresentedModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var environmentNamespace

    func body(content: Content) -> some View {
        content
            .environment(
                \.sheetHeroNamespace,
                environmentNamespace ?? SheetHeroGeometry.currentNamespace
            )
            .minSheetCornerRadius()
            .onAppear { SheetHeroGeometry.enterPresentedSheet() }
            .onDisappear { SheetHeroGeometry.leavePresentedSheet() }
    }
}

/// Captures the presenting view's zoom namespace and injects it into presented
/// content. SwiftUI does not carry that environment across presentation
/// boundaries, and the global stack is wrong when a parent re-renders.
private struct SheetFromHeroModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    @Binding var item: Item?
    var sourceID: ((Item) -> String?)?
    var capturedNamespace: Namespace.ID? = nil
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        let captured = capturedNamespace ?? namespace ?? SheetHeroGeometry.currentNamespace
        content.sheet(item: $item, onDismiss: onDismiss) { value in
            // Zoom must be the outermost modifier on this presented sheet.
            sheetContent(value)
                .environment(\.sheetHeroNamespace, captured)
                .environment(\.sheetHeroAllowsZoom, true)
                .minSheetCornerRadius()
                .sheetHeroDestination(id: sourceID?(value), namespace: captured)
        }
    }
}

private struct SheetFromHeroPresentedModifier<SheetContent: View>: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    @Binding var isPresented: Bool
    var sourceID: String?
    var capturedNamespace: Namespace.ID? = nil
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        let captured = capturedNamespace ?? namespace ?? SheetHeroGeometry.currentNamespace
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            sheetContent()
                .environment(\.sheetHeroNamespace, captured)
                .environment(\.sheetHeroAllowsZoom, true)
                .minSheetCornerRadius()
                .sheetHeroDestination(id: sourceID, namespace: captured)
        }
    }
}

extension View {
    /// Installs a shared zoom namespace so source images and presented sheets
    /// can morph as one persistent picture.
    public func sheetHeroContainer() -> some View {
        modifier(SheetHeroContainerModifier())
    }

    /// Overlay windows (floating mini player) keep an isolated namespace so
    /// they cannot steal `currentNamespace` from the main window's tiles.
    public func sheetHeroOverlayContainer() -> some View {
        modifier(SheetHeroContainerModifier(participatesInGlobalStack: false))
    }

    /// Re-applies the presenting container's zoom namespace onto presented
    /// sheet or full-screen cover content. SwiftUI often does not carry the
    /// presenting environment across the presentation boundary.
    public func sheetHeroPresented() -> some View {
        modifier(SheetHeroPresentedModifier())
    }

    /// Presents a sheet and forwards this view's zoom namespace into it.
    public func sheetFromHero<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(
            SheetFromHeroModifier(
                item: item,
                onDismiss: onDismiss,
                sheetContent: content
            )
        )
    }

    /// Like `sheetFromHero(item:)` and morphs the sheet out of `sourceID`.
    public func sheetFromHero<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        sourceID: @escaping (Item) -> String?,
        namespace: Namespace.ID? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(
            SheetFromHeroModifier(
                item: item,
                sourceID: sourceID,
                capturedNamespace: namespace,
                onDismiss: onDismiss,
                sheetContent: content
            )
        )
    }

    /// Bool-presented variant of `sheetFromHero(item:)` — same namespace forwarding.
    public func sheetFromHero<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            SheetFromHeroPresentedModifier(
                isPresented: isPresented,
                onDismiss: onDismiss,
                sheetContent: content
            )
        )
    }

    /// Like `sheetFromHero(isPresented:)` and morphs the sheet out of `sourceID`.
    public func sheetFromHero<SheetContent: View>(
        isPresented: Binding<Bool>,
        sourceID: String?,
        namespace: Namespace.ID? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(
            SheetFromHeroPresentedModifier(
                isPresented: isPresented,
                sourceID: sourceID,
                capturedNamespace: namespace,
                onDismiss: onDismiss,
                sheetContent: content
            )
        )
    }

    /// Marks a key image as the origin of a sheet. Pair with
    /// `sheetHeroDestination(id:)` using the same id.
    public func sheetHeroSource(
        id: String,
        cornerRadius: CGFloat = MinCornerRadius.artTile
    ) -> some View {
        modifier(SheetHeroSourceModifier(id: id, cornerRadius: cornerRadius))
    }

    /// Morphs this presented sheet out of the matching source image, and back
    /// into it, using the system zoom transition. Prefer `sheetFromHero`
    /// so zoom sits on the presented sheet from the first frame.
    @ViewBuilder
    public func sheetHeroDestination(id: String?, namespace: Namespace.ID? = nil) -> some View {
        if let id, !id.isEmpty {
            // Runs while the presenter builds this sheet's content, which is
            // before UIKit presents it and before the sheet itself renders.
            let _ = SheetHeroSession.expectZoomPresentation(id)
            modifier(SheetHeroDestinationModifier(id: id, explicitNamespace: namespace))
        } else {
            self
        }
    }
}
