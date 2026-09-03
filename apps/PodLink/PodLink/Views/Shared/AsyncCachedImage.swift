import SwiftUI
import UIKit

struct AsyncCachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let fadeInOnLoad: Bool
    let initialBlurRadius: CGFloat
    let fadeInDuration: Double
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var cachedImage: UIImage?
    @State private var hasAnimatedIn = false

    private static func isSupportedRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return false
        }
        return true
    }

    /// Synchronous memory-cache hit so the first frame can show art without flashing the placeholder (same idea as WatchedIt list rows).
    private static func initialCachedImage(url: URL?) -> UIImage? {
        guard let url, isSupportedRemoteURL(url),
              let image = ImageCache.shared.getImage(for: url),
              image.size.width > 0 && image.size.height > 0 else {
            return nil
        }
        return image
    }

    init(
        url: URL?,
        fadeInOnLoad: Bool = false,
        initialBlurRadius: CGFloat = 0,
        fadeInDuration: Double = 0.2,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.fadeInOnLoad = fadeInOnLoad
        self.initialBlurRadius = initialBlurRadius
        self.fadeInDuration = fadeInDuration
        self.content = content
        self.placeholder = placeholder
        let memoryHit = Self.initialCachedImage(url: url)
        _cachedImage = State(initialValue: memoryHit)
        _hasAnimatedIn = State(initialValue: memoryHit != nil ? true : !fadeInOnLoad)
    }

    var body: some View {
        Group {
            if let url, Self.isSupportedRemoteURL(url) {
                if let cachedImage, cachedImage.size.width > 0 && cachedImage.size.height > 0 {
                    styledImage(content(Image(uiImage: cachedImage)))
                } else {
                    placeholder()
                        .task(id: url) {
                            if let cached = await ImageCache.shared.getImageAsync(for: url),
                               cached.size.width > 0 && cached.size.height > 0 {
                                cachedImage = cached
                            } else {
                                await prefetchImage(from: url)
                            }
                        }
                }
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { _, _ in
            cachedImage = nil
            hasAnimatedIn = !fadeInOnLoad
        }
    }

    @ViewBuilder
    private func styledImage<ImageView: View>(_ imageView: ImageView) -> some View {
        imageView
            .opacity(hasAnimatedIn ? 1 : 0)
            .onAppear {
                guard fadeInOnLoad, !hasAnimatedIn else { return }
                withAnimation(.easeOut(duration: fadeInDuration)) {
                    hasAnimatedIn = true
                }
            }
    }

    private func prefetchImage(from url: URL) async {
        guard Self.isSupportedRemoteURL(url) else { return }
        if let cached = await ImageCache.shared.getImageAsync(for: url),
           cached.size.width > 0 && cached.size.height > 0 {
            await MainActor.run {
                cachedImage = cached
            }
            return
        }

        await cacheImage(from: url)
    }

    private func cacheImage(from url: URL) async {
        await ImageCache.shared.prefetchImage(from: url)
        if let cached = await ImageCache.shared.getImageAsync(for: url) {
            await MainActor.run {
                cachedImage = cached
            }
        }
    }
}

extension AsyncCachedImage where Placeholder == Color {
    init(
        url: URL?,
        fadeInOnLoad: Bool = false,
        initialBlurRadius: CGFloat = 0,
        fadeInDuration: Double = 0.2,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.fadeInOnLoad = fadeInOnLoad
        self.initialBlurRadius = initialBlurRadius
        self.fadeInDuration = fadeInDuration
        self.content = content
        self.placeholder = { Color(.tertiarySystemFill) }
        let memoryHit = Self.initialCachedImage(url: url)
        _cachedImage = State(initialValue: memoryHit)
        _hasAnimatedIn = State(initialValue: memoryHit != nil ? true : !fadeInOnLoad)
    }
}
