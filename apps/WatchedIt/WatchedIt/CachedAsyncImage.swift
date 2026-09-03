//
//  CachedAsyncImage.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
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
    
    init(
        url: URL?,
        fadeInOnLoad: Bool = true,
        initialBlurRadius: CGFloat = 40,
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
        _cachedImage = State(initialValue: nil)
        _hasAnimatedIn = State(initialValue: !fadeInOnLoad)
    }
    
    var body: some View {
        Group {
            if let url = url, Self.isSupportedRemoteURL(url) {
                if let cachedImage = cachedImage, cachedImage.size.width > 0 && cachedImage.size.height > 0 {
                    styledImage(content(Image(uiImage: cachedImage)))
                } else {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            placeholder()
                        case .success(let image):
                            styledImage(content(image))
                                .task {
                                    // Cache the image asynchronously
                                    await cacheImage(from: url)
                                }
                        case .failure(_):
                            placeholder()
                        @unknown default:
                            placeholder()
                        }
                    }
                    .task {
                        // Load cache asynchronously to avoid blocking transitions.
                        if cachedImage == nil {
                            if let cached = await ImageCache.shared.getImageAsync(for: url),
                               cached.size.width > 0 && cached.size.height > 0 {
                                cachedImage = cached
                            } else {
                                await prefetchImage(from: url)
                            }
                        }
                    }
                }
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { _, _ in
            hasAnimatedIn = !fadeInOnLoad
        }
    }

    @ViewBuilder
    private func styledImage<ImageView: View>(_ imageView: ImageView) -> some View {
        imageView
            .opacity(hasAnimatedIn ? 1 : 0)
            .blur(radius: hasAnimatedIn ? 0 : initialBlurRadius)
            .onAppear {
                guard fadeInOnLoad, !hasAnimatedIn else { return }
                withAnimation(.easeOut(duration: fadeInDuration)) {
                    hasAnimatedIn = true
                }
            }
    }
    
    private func prefetchImage(from url: URL) async {
        guard Self.isSupportedRemoteURL(url) else { return }
        // Check cache again (might have been loaded by another view)
        if let cached = await ImageCache.shared.getImageAsync(for: url),
           cached.size.width > 0 && cached.size.height > 0 {
            await MainActor.run {
                cachedImage = cached
            }
            return
        }
        
        // Start loading in background
        await cacheImage(from: url)
    }
    
    private func cacheImage(from url: URL) async {
        guard Self.isSupportedRemoteURL(url) else { return }
        // Check cache first (might have been loaded by another view)
        if let cached = await ImageCache.shared.getImageAsync(for: url) {
            await MainActor.run {
                cachedImage = cached
            }
            return
        }
        
        // Download and cache
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    return
                }
            }
            
            if let uiImage = UIImage(data: data),
               uiImage.size.width > 0 && uiImage.size.height > 0 {
                ImageCache.shared.setImage(uiImage, for: url)
                await MainActor.run {
                    cachedImage = uiImage
                }
            }
        } catch {
            // Silently handle errors - image will show placeholder
        }
    }
}

