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

    /// Mini-player artwork in a secondary overlay window. `matchedTransitionSource`
    /// hides that live view, so those sources keep a covered idle copy.
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
    private(set) var zoomDestinationCount = 0
    private var dismissHandlers: [() -> Void] = []

    /// True while a destination is using iOS 18 `navigationTransition(.zoom)`.
    var usesSystemZoom: Bool { zoomDestinationCount > 0 }

    func enterZoomDestination() {
        zoomDestinationCount += 1
    }

    func leaveZoomDestination() {
        zoomDestinationCount = max(0, zoomDestinationCount - 1)
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
        // that source keeps a hit-test-free copy that cover opacity hides
        // while the sheet is the flying object.
        if allowsZoom, let namespace {
            if #available(iOS 18.0, *) {
                let matched = sourced
                    .matchedTransitionSource(id: id, in: namespace) { source in
                        source.clipShape(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                    }
                if SheetHeroID.isMiniPlayer(id) {
                    matched.overlay {
                        content
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .modifier(SheetHeroCoverOpacity(id: id))
                    }
                } else {
                    matched
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
private struct SheetHeroCoverOpacity: ViewModifier {
    let id: String
    var session = SheetHeroSession.shared

    func body(content: Content) -> some View {
        content
            .opacity(session.isCovered(id) ? 0 : 1)
            .transaction { $0.animation = nil }
    }
}

/// Enters the zoom session as soon as the destination hosting view exists so
/// scrim setup does not install a custom dim plate on the first zoom frames.
private struct SheetHeroZoomSessionProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.enter()
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {}

    static func dismantleUIView(_ uiView: ProbeView, coordinator: ()) {
        uiView.leave()
    }

    final class ProbeView: UIView {
        private var active = false

        func enter() {
            guard !active else { return }
            active = true
            SheetHeroSession.shared.enterZoomDestination()
        }

        func leave() {
            guard active else { return }
            active = false
            SheetHeroSession.shared.leaveZoomDestination()
        }
    }
}
#endif

private struct SheetHeroDestinationModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var environmentNamespace
    let id: String

    private var namespace: Namespace.ID? {
        environmentNamespace ?? SheetHeroGeometry.currentNamespace
    }

    func body(content: Content) -> some View {
        let tagged = content
            .environment(\.sheetHeroPresentedID, id)
            .environment(\.sheetHeroNamespace, namespace)
            .environment(\.sheetHeroAllowsZoom, true)
        #if os(iOS)
        applyZoom(tagged)
            .background {
                SheetHeroZoomSessionProbe()
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            .onAppear {
                if SheetHeroID.isMiniPlayer(id) {
                    DispatchQueue.main.async {
                        SheetHeroSession.shared.cover(id)
                    }
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

/// Captures the presenting view's zoom namespace and injects it into sheet
/// content. SwiftUI does not carry that environment across `.sheet`, and the
/// global stack is wrong when a parent container re-renders.
private struct SheetFromHeroModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    @Binding var item: Item?
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        let captured = namespace ?? SheetHeroGeometry.currentNamespace
        content.sheet(item: $item, onDismiss: onDismiss) { value in
            sheetContent(value)
                .environment(\.sheetHeroNamespace, captured)
                .environment(\.sheetHeroAllowsZoom, true)
                .minSheetCornerRadius()
        }
    }
}

private struct SheetFromHeroPresentedModifier<SheetContent: View>: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    @Binding var isPresented: Bool
    var onDismiss: (() -> Void)?
    @ViewBuilder var sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        let captured = namespace ?? SheetHeroGeometry.currentNamespace
        content.sheet(isPresented: $isPresented, onDismiss: onDismiss) {
            sheetContent()
                .environment(\.sheetHeroNamespace, captured)
                .environment(\.sheetHeroAllowsZoom, true)
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
    /// into it, using the system zoom transition.
    @ViewBuilder
    public func sheetHeroDestination(id: String?) -> some View {
        if let id, !id.isEmpty {
            modifier(SheetHeroDestinationModifier(id: id))
        } else {
            self
        }
    }
}
