import Observation
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
        let existingOnScreen = onScreenIDs.contains(id)
        guard EdgeSwipeToDismiss.shouldReplaceHeroFrame(
            existing: frames[id],
            next: frame,
            existingOnScreen: existingOnScreen,
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
        #if os(iOS)
        let stored = frames[id]
        let live = liveFrame(for: id, onScreenOnly: true)
        if let stored, let live {
            // Live on-screen tiles win when they are rest-size. Presenter
            // scale is smaller, so the frozen rest frame still wins then.
            return live.width >= stored.width * 0.97 ? live : stored
        }
        return stored ?? live ?? liveFrame(for: id, onScreenOnly: false)
        #else
        frames[id]
        #endif
    }

    public static func cornerRadius(for id: String) -> CGFloat {
        radii[id] ?? MinCornerRadius.artTile
    }

    public static func isOnScreen(_ id: String) -> Bool {
        #if os(iOS)
        if liveFrame(for: id, onScreenOnly: true) != nil { return true }
        #endif
        return onScreenIDs.contains(id)
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

    #if os(iOS)
    private struct LiveHero {
        var id: String
        var frame: () -> CGRect?
        weak var owner: AnyObject?
    }

    private static var liveHeroes: [ObjectIdentifier: LiveHero] = [:]

    static func registerLiveHero(id: String, owner: AnyObject, frame: @escaping () -> CGRect?) {
        liveHeroes[ObjectIdentifier(owner)] = LiveHero(id: id, frame: frame, owner: owner)
    }

    static func unregisterLiveHero(owner: AnyObject) {
        liveHeroes.removeValue(forKey: ObjectIdentifier(owner))
    }

    private static func liveFrame(for id: String, onScreenOnly: Bool) -> CGRect? {
        liveHeroes = liveHeroes.filter { $0.value.owner != nil }
        var best: CGRect?
        for item in liveHeroes.values where item.id == id {
            guard let frame = item.frame(), frame.width > 1, frame.height > 1 else { continue }
            if onScreenOnly && !sheetHeroFrameIsOnScreen(frame) { continue }
            if let current = best {
                if frame.width > current.width { best = frame }
            } else {
                best = frame
            }
        }
        return best
    }
    #endif

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

    /// Root home↔sheet morphs. A sheet sitting on another sheet does not.
    public var sheetHeroAllowsZoom: Bool {
        get { self[SheetHeroAllowsZoomKey.self] }
        set { self[SheetHeroAllowsZoomKey.self] = newValue }
    }
}

private struct SheetHeroContainerModifier: ViewModifier {
    @Namespace private var namespace

    func body(content: Content) -> some View {
        SheetHeroGeometry.activate(namespace)
        return content
            .environment(\.sheetHeroNamespace, namespace)
            .onAppear { SheetHeroGeometry.pushNamespace(namespace) }
            .onDisappear { SheetHeroGeometry.popNamespace(namespace) }
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
                            SheetHeroImageCapture(id: id, cornerRadius: cornerRadius)
                                .frame(width: 0, height: 0)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        #endif
                }
            }
            .modifier(SheetHeroCoverOpacity(id: id))

        #if os(iOS)
        // Nested sheets skip matchedTransitionSource — zooming a sheet that
        // sits on another sheet is too complex, so those present normally.
        if allowsZoom, let namespace {
            if #available(iOS 18.0, *) {
                // `matchedTransitionSource` hides its live view while (and
                // sometimes after) the morph — especially in a secondary
                // overlay window like the floating mini player. Keep a
                // hit-test-free copy on top so artwork stays visible when
                // idle; cover opacity hides that copy during the flight.
                sourced
                    .matchedTransitionSource(id: id, in: namespace) { source in
                        source
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            )
                    }
                    .overlay {
                        content
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .modifier(SheetHeroCoverOpacity(id: id))
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
        // UIKit probes record window frames. SwiftUI `.global` is a different
        // space and was sending grid dismisses to a stale corner.
        _ = frame
        #else
        SheetHeroGeometry.update(
            id: id,
            frame: frame,
            cornerRadius: cornerRadius,
            onScreen: true
        )
        #endif
    }
}

#if os(iOS)
/// Walks the source tile for a UIImage so dismiss can fade that art into the
/// returning card when the live thumbnail has scrolled off-screen.
private struct SheetHeroImageCapture: UIViewRepresentable {
    let id: String
    var cornerRadius: CGFloat = MinCornerRadius.artTile

    func makeUIView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.heroID = id
        view.cornerRadius = cornerRadius
        return view
    }

    func updateUIView(_ uiView: CaptureView, context: Context) {
        uiView.heroID = id
        uiView.cornerRadius = cornerRadius
        if uiView.window != nil {
            SheetHeroGeometry.registerLiveHero(id: id, owner: uiView) { [weak uiView] in
                uiView?.windowFrame()
            }
            uiView.recordWindowFrame()
        }
        uiView.captureSoon()
    }

    final class CaptureView: UIView {
        var heroID: String = ""
        var cornerRadius: CGFloat = MinCornerRadius.artTile
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
            if window != nil {
                SheetHeroGeometry.registerLiveHero(id: heroID, owner: self) { [weak self] in
                    self?.windowFrame()
                }
                recordWindowFrame()
            } else {
                SheetHeroGeometry.unregisterLiveHero(owner: self)
            }
            captureSoon()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            recordWindowFrame()
            captureSoon()
        }

        /// UIKit window coords — the same space the dismiss clip converts from.
        func windowFrame() -> CGRect? {
            guard let window else { return nil }
            var node: UIView? = superview
            var hops = 0
            while let view = node, hops < 8 {
                if view.bounds.width > 8, view.bounds.height > 8 {
                    return view.convert(view.bounds, to: window)
                }
                node = view.superview
                hops += 1
            }
            return nil
        }

        func recordWindowFrame() {
            guard !heroID.isEmpty, let frame = windowFrame() else { return }
            SheetHeroGeometry.update(
                id: heroID,
                frame: frame,
                cornerRadius: cornerRadius,
                onScreen: sheetHeroFrameIsOnScreen(frame)
            )
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

private struct SheetHeroCoverOpacity: ViewModifier {
    let id: String
    var session = SheetHeroSession.shared

    func body(content: Content) -> some View {
        content
            .opacity(session.isCovered(id) ? 0 : 1)
            .transaction { $0.animation = nil }
    }
}

private struct SheetHeroDestinationModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var environmentNamespace
    let id: String
    /// Captured when this destination is first inserted. A parent sheet's
    /// `onAppear` must not later steal zoom from the root sheet.
    @State private var allowsZoom: Bool = !SheetHeroGeometry.isInsidePresentedSheet

    private var namespace: Namespace.ID? {
        environmentNamespace ?? SheetHeroGeometry.currentNamespace
    }

    private var shouldZoom: Bool {
        // Captured at insert time. Do not AND with environmentAllowsZoom:
        // `sheetHeroPresented` sits inside this modifier and forces that
        // value false so nested sources skip matching.
        allowsZoom
    }

    func body(content: Content) -> some View {
        let tagged = content
            .environment(\.sheetHeroPresentedID, id)
            .environment(\.sheetHeroNamespace, namespace)
            .environment(\.sheetHeroAllowsZoom, shouldZoom)
        #if os(iOS)
        applyZoom(
            tagged
                .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        )
        .onAppear {
            guard shouldZoom else { return }
            // After the system has snapshotted the source for the open zoom.
            DispatchQueue.main.async {
                SheetHeroSession.shared.cover(id)
            }
        }
        .onDisappear {
            SheetHeroSession.shared.uncover(id)
        }
        #else
        tagged
        #endif
    }

    @ViewBuilder
    private func applyZoom<V: View>(_ view: V) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *), shouldZoom, let namespace {
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
            // Sources and nested sheets inside this presentation must not
            // zoom. The destination modifier (outside this one) still zooms
            // the root sheet itself.
            .environment(\.sheetHeroAllowsZoom, false)
            .minSheetCornerRadius()
            .onAppear { SheetHeroGeometry.enterPresentedSheet() }
            .onDisappear { SheetHeroGeometry.leavePresentedSheet() }
    }
}

/// Captures the presenting view's zoom namespace and injects it into sheet
/// content. SwiftUI does not carry that environment across `.sheet`, and the
/// global stack is wrong when a parent container re-renders.
private struct SheetFromHeroModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    @Environment(\.sheetHeroAllowsZoom) private var allowsZoom
    @Binding var item: Item?
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        let captured = namespace ?? SheetHeroGeometry.currentNamespace
        // Nested presenters (search, show) already flipped allowsZoom off.
        let capturedAllowsZoom = allowsZoom && !SheetHeroGeometry.isInsidePresentedSheet
        content.sheet(item: $item, onDismiss: onDismiss) { value in
            sheetContent(value)
                .environment(\.sheetHeroNamespace, captured)
                .environment(\.sheetHeroAllowsZoom, capturedAllowsZoom)
                .minSheetCornerRadius()
        }
    }
}

private struct SheetFromHeroPresentedModifier<SheetContent: View>: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    @Environment(\.sheetHeroAllowsZoom) private var allowsZoom
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        let captured = namespace ?? SheetHeroGeometry.currentNamespace
        let capturedAllowsZoom = allowsZoom && !SheetHeroGeometry.isInsidePresentedSheet
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            sheetContent()
                .environment(\.sheetHeroNamespace, captured)
                .environment(\.sheetHeroAllowsZoom, capturedAllowsZoom)
                .minSheetCornerRadius()
        }
    }
}

extension View {
    /// Installs a shared zoom namespace so source images and presented sheets
    /// can morph as one persistent picture.
    public func sheetHeroContainer() -> some View {
        modifier(SheetHeroContainerModifier())
    }

    /// Re-applies the presenting container's zoom namespace onto presented
    /// sheet or full-screen cover content. SwiftUI often does not carry the
    /// presenting environment across the presentation boundary.
    public func sheetHeroPresented() -> some View {
        modifier(SheetHeroPresentedModifier())
    }

    /// Presents a sheet and forwards this view's zoom namespace into it.
    /// Nested sheets (already sitting on another sheet) skip the zoom.
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

    /// Marks a key image as the origin of a sheet. Pair with
    /// `sheetHeroDestination(id:)` using the same id.
    public func sheetHeroSource(
        id: String,
        cornerRadius: CGFloat = MinCornerRadius.artTile
    ) -> some View {
        modifier(SheetHeroSourceModifier(id: id, cornerRadius: cornerRadius))
    }

    /// Morphs this presented sheet out of the matching source image, and back
    /// into it on a regular dismiss. No-ops when this sheet sits on another
    /// sheet — only the root presentation over home zooms.
    @ViewBuilder
    public func sheetHeroDestination(id: String?) -> some View {
        if let id, !id.isEmpty {
            modifier(SheetHeroDestinationModifier(id: id))
        } else {
            self
        }
    }
}
