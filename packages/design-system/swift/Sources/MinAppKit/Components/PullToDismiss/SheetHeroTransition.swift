import Observation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Shared motion for zooming a sheet out of a matching key image.
public enum SheetHeroMotion {
    /// Open zoom and scrim fade-in.
    public static let openDuration: TimeInterval = 0.42
    /// After the flying image lands, fade it out so the real thumbnail
    /// (and anything on top of it) can appear through it.
    public static let overlayFadeDuration: TimeInterval = 0.16
}

/// Stable ids for a source image and the sheet it opens. The two must match.
public enum SheetHeroID {
    public static func podcast(_ id: String) -> String { "podcast:\(id)" }
    public static func episode(_ id: String) -> String { "episode:\(id)" }
    public static func movie(_ id: String) -> String { "movie:\(id)" }
    public static func video(_ id: String) -> String { "video:\(id)" }
    public static func channel(_ id: String) -> String { "channel:\(id)" }
}

/// Last on-screen frames of hero sources, used to fling a sheet back into the
/// thumbnail when the system zoom transition is not driving dismiss.
@MainActor
public enum SheetHeroGeometry {
    private static var frames: [String: CGRect] = [:]
    private static var radii: [String: CGFloat] = [:]
    private static var namespaceStack: [Namespace.ID] = []

    public static func update(id: String, frame: CGRect, cornerRadius: CGFloat) {
        guard frame.width > 1, frame.height > 1 else { return }
        frames[id] = frame
        radii[id] = cornerRadius
    }

    public static func frame(for id: String) -> CGRect? {
        frames[id]
    }

    public static func cornerRadius(for id: String) -> CGFloat {
        radii[id] ?? MinCornerRadius.artTile
    }

    static var currentNamespace: Namespace.ID? {
        namespaceStack.last
    }

    static func pushNamespace(_ namespace: Namespace.ID) {
        namespaceStack.append(namespace)
    }

    static func popNamespace(_ namespace: Namespace.ID) {
        if let index = namespaceStack.lastIndex(of: namespace) {
            namespaceStack.remove(at: index)
        }
    }
}

/// Shows the real thumbnail only once the flying image covers it.
@MainActor
@Observable
final class SheetHeroReveal {
    static let shared = SheetHeroReveal()

    private(set) var revealedIDs: Set<String> = []

    func reveal(_ id: String?) {
        guard let id, !id.isEmpty else { return }
        revealedIDs.insert(id)
    }

    func reset(_ id: String?) {
        guard let id else { return }
        revealedIDs.remove(id)
    }

    func isRevealed(_ id: String) -> Bool {
        revealedIDs.contains(id)
    }
}

private struct SheetHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct SheetHeroPresentedIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
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
}

private struct SheetHeroContainerModifier: ViewModifier {
    @Namespace private var namespace

    func body(content: Content) -> some View {
        content
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

private struct SheetHeroSourceModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    let id: String
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let sourced = content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        SheetHeroGeometry.update(
                            id: id,
                            frame: proxy.frame(in: .global),
                            cornerRadius: cornerRadius
                        )
                    }
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        SheetHeroGeometry.update(
                            id: id,
                            frame: frame,
                            cornerRadius: cornerRadius
                        )
                    }
            }
        }
        #if os(iOS)
        if let namespace {
            if #available(iOS 18.0, *) {
                sourced
                    .matchedTransitionSource(id: id, in: namespace) { source in
                        source.clipShape(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                    }
                    .overlay {
                        SheetHeroLandingClone(id: id) { content }
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
}

/// Hidden until the flying image covers this frame, then shown underneath
/// so the morph can fade out onto the real tile.
private struct SheetHeroLandingClone<Inner: View>: View {
    let id: String
    @ViewBuilder var inner: () -> Inner
    private var reveal = SheetHeroReveal.shared

    var body: some View {
        inner()
            .opacity(reveal.isRevealed(id) ? 1 : 0)
            .animation(nil, value: reveal.revealedIDs.contains(id))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct SheetHeroDestinationModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var environmentNamespace
    let id: String

    private var namespace: Namespace.ID? {
        environmentNamespace ?? SheetHeroGeometry.currentNamespace
    }

    func body(content: Content) -> some View {
        let tagged = content.environment(\.sheetHeroPresentedID, id)
        #if os(iOS)
        let painted = tagged.background(Color(uiColor: .systemBackground).ignoresSafeArea())
        if let namespace {
            if #available(iOS 18.0, *) {
                painted.navigationTransition(.zoom(sourceID: id, in: namespace))
            } else {
                painted
            }
        } else {
            painted
        }
        #else
        tagged
        #endif
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
        environment(\.sheetHeroNamespace, SheetHeroGeometry.currentNamespace)
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
    /// into it on a regular dismiss.
    @ViewBuilder
    public func sheetHeroDestination(id: String?) -> some View {
        if let id, !id.isEmpty {
            modifier(SheetHeroDestinationModifier(id: id))
        } else {
            self
        }
    }
}
