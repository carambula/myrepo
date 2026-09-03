import SwiftUI
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct BlurredAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let fadeInOnLoad: Bool
    let initialBlurRadius: CGFloat
    let fadeInDuration: Double
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var hasAnimatedIn = false

    init(
        url: URL?,
        fadeInOnLoad: Bool = true,
        initialBlurRadius: CGFloat = 30,
        fadeInDuration: Double = 0.22,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.fadeInOnLoad = fadeInOnLoad
        self.initialBlurRadius = initialBlurRadius
        self.fadeInDuration = fadeInDuration
        self.content = content
        self.placeholder = placeholder
        _hasAnimatedIn = State(initialValue: !fadeInOnLoad)
    }

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder()
                    case .success(let image):
                        styledImage(content(image))
                    case .failure:
                        placeholder()
                    @unknown default:
                        placeholder()
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
}

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let cacheTTL: TimeInterval
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        cacheTTL: TimeInterval = 60 * 60 * 24 * 7,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.cacheTTL = cacheTTL
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url?.absoluteString) {
                await load()
            }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }

        phase = .empty

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20

        do {
            let data = try await UnifiedDataCache.shared.data(
                for: request,
                cacheKey: "image:\(url.absoluteString)",
                ttl: cacheTTL
            )
            guard let image = imageFromData(data) else {
                throw APIError.badResponse
            }
            phase = .success(image)
        } catch {
            phase = .failure(error)
        }
    }

    private func imageFromData(_ data: Data) -> Image? {
        // Skip PDF payloads; race artwork expects raster images.
        if data.starts(with: [0x25, 0x50, 0x44, 0x46, 0x2D]) {
            return nil
        }
        #if os(iOS) || os(tvOS) || os(watchOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
