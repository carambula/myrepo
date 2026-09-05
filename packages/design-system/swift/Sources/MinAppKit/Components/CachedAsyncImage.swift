#if canImport(UIKit)
import UIKit
#endif
import SwiftUI

/// Image view with automatic memory + disk caching.
///
/// Consolidates `CachedAsyncImage` (WatchedIt, YourTube) and `AsyncCachedImage` (PodLink) into one
/// configurable component. Supports fade-in animation, blur-up transition, and sync cache hits.
///
/// ```swift
/// CachedAsyncImage(url: posterURL) { image in
///     image.resizable().aspectRatio(contentMode: .fill)
/// } placeholder: {
///     Color(.tertiarySystemFill)
/// }
/// ```
public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    let fadeInOnLoad: Bool
    let initialBlurRadius: CGFloat

    @State private var cachedImage: UIImage?
    @State private var hasAnimatedIn: Bool
    @State private var loadedFromCache: Bool = false

    public init(
        url: URL?,
        fadeInOnLoad: Bool = true,
        initialBlurRadius: CGFloat = 30,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        self.fadeInOnLoad = fadeInOnLoad
        self.initialBlurRadius = initialBlurRadius

        // Synchronous memory-cache check for zero-flicker rendering
        if let url, let cached = ImageCache.shared.getImage(for: url) {
            _cachedImage = State(initialValue: cached)
            _hasAnimatedIn = State(initialValue: true)
        } else {
            _cachedImage = State(initialValue: nil)
            _hasAnimatedIn = State(initialValue: false)
        }
    }

    public var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .blur(radius: hasAnimatedIn ? 0 : initialBlurRadius)
                    .animation(fadeInOnLoad && !loadedFromCache ? MinAnimation.standard : nil, value: hasAnimatedIn)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loadImage()
        }
        .onChange(of: url) { _, _ in
            cachedImage = nil
            hasAnimatedIn = false
            loadedFromCache = false
        }
    }

    private func loadImage() async {
        guard let url else { return }

        if let cached = ImageCache.shared.getImage(for: url) {
            cachedImage = cached
            loadedFromCache = true
            hasAnimatedIn = true
            return
        }

        if let fetched = await ImageCache.shared.prefetchImage(from: url) {
            cachedImage = fetched
            loadedFromCache = false
            withAnimation { hasAnimatedIn = true }
        }
    }
}

extension CachedAsyncImage where Placeholder == Color {
    /// Convenience initializer with a default placeholder.
    public init(
        url: URL?,
        fadeInOnLoad: Bool = true,
        initialBlurRadius: CGFloat = 30,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.init(
            url: url,
            fadeInOnLoad: fadeInOnLoad,
            initialBlurRadius: initialBlurRadius,
            content: content,
            placeholder: { Color(.tertiarySystemFill) }
        )
    }
}
