import SwiftUI

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
}

private struct SheetHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

private struct SheetHeroPresentedIDKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var sheetHeroNamespace: Namespace.ID? {
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
        content.environment(\.sheetHeroNamespace, namespace)
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
                sourced.matchedTransitionSource(id: id, in: namespace)
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

private struct SheetHeroDestinationModifier: ViewModifier {
    @Environment(\.sheetHeroNamespace) private var namespace
    let id: String

    func body(content: Content) -> some View {
        let tagged = content.environment(\.sheetHeroPresentedID, id)
        #if os(iOS)
        if let namespace {
            if #available(iOS 18.0, *) {
                tagged.navigationTransition(.zoom(sourceID: id, in: namespace))
            } else {
                tagged
            }
        } else {
            tagged
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
