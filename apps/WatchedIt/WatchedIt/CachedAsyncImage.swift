//
//  CachedAsyncImage.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let previewURL: URL?
    let fadeInOnLoad: Bool
    let initialBlurRadius: CGFloat
    let fadeInDuration: Double
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var cachedImage: UIImage?
    @State private var hasAnimatedIn: Bool
    @State private var displayedURL: URL?

    private static func isSupportedRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return false
        }
        return true
    }

    private static func memoryImage(for url: URL?) -> UIImage? {
        guard let url, isSupportedRemoteURL(url),
              let image = ImageCache.shared.getImage(for: url),
              image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        return image
    }

    init(
        url: URL?,
        previewURL: URL? = nil,
        fadeInOnLoad: Bool = true,
        initialBlurRadius: CGFloat = 40,
        fadeInDuration: Double = 0.2,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.previewURL = previewURL
        self.fadeInOnLoad = fadeInOnLoad
        self.initialBlurRadius = initialBlurRadius
        self.fadeInDuration = fadeInDuration
        self.content = content
        self.placeholder = placeholder
        if let full = Self.memoryImage(for: url) {
            _cachedImage = State(initialValue: full)
            _hasAnimatedIn = State(initialValue: true)
            _displayedURL = State(initialValue: url)
        } else if let preview = Self.memoryImage(for: previewURL) {
            _cachedImage = State(initialValue: preview)
            _hasAnimatedIn = State(initialValue: true)
            _displayedURL = State(initialValue: previewURL)
        } else {
            _cachedImage = State(initialValue: nil)
            _hasAnimatedIn = State(initialValue: !fadeInOnLoad)
            _displayedURL = State(initialValue: nil)
        }
    }

    var body: some View {
        Group {
            if let cachedImage, cachedImage.size.width > 0, cachedImage.size.height > 0 {
                styledImage(content(Image(uiImage: cachedImage)))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await loadImages() }
        .onChange(of: url) { _, _ in
            if let full = Self.memoryImage(for: url) {
                cachedImage = full
                displayedURL = url
                hasAnimatedIn = true
            } else if let preview = Self.memoryImage(for: previewURL) {
                cachedImage = preview
                displayedURL = previewURL
                hasAnimatedIn = true
            } else {
                cachedImage = nil
                displayedURL = nil
                hasAnimatedIn = !fadeInOnLoad
            }
        }
    }

    @ViewBuilder
    private func styledImage<ImageView: View>(_ imageView: ImageView) -> some View {
        let skipBlur = displayedURL != nil
        imageView
            .opacity(hasAnimatedIn ? 1 : 0)
            .blur(radius: (hasAnimatedIn || skipBlur) ? 0 : initialBlurRadius)
            .onAppear {
                guard fadeInOnLoad, !hasAnimatedIn, !skipBlur else {
                    hasAnimatedIn = true
                    return
                }
                withAnimation(.easeOut(duration: fadeInDuration)) {
                    hasAnimatedIn = true
                }
            }
    }

    private func loadImages() async {
        if let url,
           let cached = await ImageCache.shared.getImageAsync(for: url),
           cached.size.width > 0, cached.size.height > 0 {
            await MainActor.run { applyLoadedImage(cached, for: url) }
            return
        }

        if displayedURL != url, let previewURL {
            if let preview = await ImageCache.shared.getImageAsync(for: previewURL),
               preview.size.width > 0, preview.size.height > 0 {
                await MainActor.run { applyLoadedImage(preview, for: previewURL) }
            } else {
                await prefetchImage(from: previewURL)
            }
        }

        if let url {
            await prefetchImage(from: url)
        }
    }

    private func applyLoadedImage(_ image: UIImage, for loadedURL: URL) {
        if displayedURL == url, loadedURL != url { return }
        cachedImage = image
        displayedURL = loadedURL
        hasAnimatedIn = true
    }

    private func prefetchImage(from url: URL) async {
        guard Self.isSupportedRemoteURL(url) else { return }
        if let cached = await ImageCache.shared.getImageAsync(for: url),
           cached.size.width > 0, cached.size.height > 0 {
            await MainActor.run { applyLoadedImage(cached, for: url) }
            return
        }
        await cacheImage(from: url)
    }

    private func cacheImage(from url: URL) async {
        guard Self.isSupportedRemoteURL(url) else { return }
        if let cached = await ImageCache.shared.getImageAsync(for: url) {
            await MainActor.run { applyLoadedImage(cached, for: url) }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return
            }
            if let uiImage = UIImage(data: data),
               uiImage.size.width > 0, uiImage.size.height > 0 {
                ImageCache.shared.setImage(uiImage, for: url)
                await MainActor.run { applyLoadedImage(uiImage, for: url) }
            }
        } catch {
            // Silently handle errors - image will show placeholder
        }
    }
}

/// Movie detail hero: list thumbnail first, then the large poster, with no blur-up.
struct MovieHeroPoster<Placeholder: View>: View {
    let path: String
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    private var previewURL: URL? {
        MovieDataService.shared.getThumbnailURL(path: path).flatMap(URL.init(string:))
    }

    private var fullURL: URL? {
        MovieDataService.shared.getLargePosterURL(path: path).flatMap(URL.init(string:))
    }

    var body: some View {
        CachedAsyncImage(
            url: fullURL,
            previewURL: previewURL,
            fadeInOnLoad: false,
            initialBlurRadius: 0
        ) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            placeholder()
        }
    }
}
