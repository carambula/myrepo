import SwiftUI

enum LinkServiceBrand: String, CaseIterable, Sendable, Equatable {
    case youtube
    case tiktok
    case instagram
    case spotify
    case appleMusic
    case applePodcasts
    case appleAppStore
    case x
    case facebook
    case threads
    case amazon
    case netflix
    case imdb
    case letterboxd
    case patreon
    case substack
    case twitch
    case vimeo
    case soundcloud
    case bandcamp
    case linkedin
    case github

    static func matching(_ url: URL) -> LinkServiceBrand? {
        matching(host: url.host ?? "")
    }

    static func matching(host rawHost: String) -> LinkServiceBrand? {
        var host = rawHost.lowercased()
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        guard !host.isEmpty else { return nil }

        for brand in LinkServiceBrand.allCases {
            if brand.hostMatches(host) {
                return brand
            }
        }
        return nil
    }

    var backgroundColor: Color {
        switch self {
        case .youtube: return Color(red: 1, green: 0, blue: 0)
        case .tiktok: return Color.black
        case .instagram: return Color(red: 0.83, green: 0.18, blue: 0.47)
        case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33)
        case .appleMusic: return Color(red: 0.98, green: 0.23, blue: 0.36)
        case .applePodcasts: return Color(red: 0.58, green: 0.22, blue: 0.95)
        case .appleAppStore: return Color(red: 0.13, green: 0.55, blue: 0.95)
        case .x: return Color.black
        case .facebook: return Color(red: 0.09, green: 0.47, blue: 0.95)
        case .threads: return Color.black
        case .amazon: return Color(red: 1, green: 0.60, blue: 0)
        case .netflix: return Color(red: 0.90, green: 0.04, blue: 0.08)
        case .imdb: return Color(red: 0.96, green: 0.77, blue: 0.09)
        case .letterboxd: return Color(red: 0.18, green: 0.61, blue: 0.86)
        case .patreon: return Color(red: 1, green: 0.26, blue: 0.30)
        case .substack: return Color(red: 1, green: 0.40, blue: 0.13)
        case .twitch: return Color(red: 0.57, green: 0.27, blue: 1)
        case .vimeo: return Color(red: 0.10, green: 0.74, blue: 1)
        case .soundcloud: return Color(red: 1, green: 0.33, blue: 0)
        case .bandcamp: return Color(red: 0.13, green: 0.75, blue: 0.80)
        case .linkedin: return Color(red: 0.04, green: 0.40, blue: 0.68)
        case .github: return Color(red: 0.14, green: 0.16, blue: 0.18)
        }
    }

    var markUsesDarkInk: Bool {
        self == .imdb || self == .amazon
    }

    var systemImage: String {
        switch self {
        case .youtube, .vimeo: return "play.fill"
        case .tiktok, .appleMusic, .soundcloud, .bandcamp: return "music.note"
        case .instagram: return "camera.fill"
        case .spotify: return "music.note.list"
        case .applePodcasts: return "mic.fill"
        case .appleAppStore: return "apple.logo"
        case .x: return "xmark"
        case .facebook: return "f.square.fill"
        case .threads: return "at"
        case .amazon: return "shippingbox.fill"
        case .netflix, .imdb, .letterboxd: return "film.fill"
        case .patreon: return "p.circle.fill"
        case .substack: return "newspaper.fill"
        case .twitch: return "gamecontroller.fill"
        case .linkedin: return "briefcase.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        }
    }

    func oembedURL(for pageURL: URL) -> URL? {
        let encoded = pageURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let encoded else { return nil }
        switch self {
        case .tiktok:
            return URL(string: "https://www.tiktok.com/oembed?url=\(encoded)")
        case .spotify:
            return URL(string: "https://open.spotify.com/oembed?url=\(encoded)")
        case .vimeo:
            return URL(string: "https://vimeo.com/api/oembed.json?url=\(encoded)")
        case .soundcloud:
            return URL(string: "https://soundcloud.com/oembed?format=json&url=\(encoded)")
        default:
            return nil
        }
    }

    private func hostMatches(_ host: String) -> Bool {
        suffixes.contains { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        }
    }

    private var suffixes: [String] {
        switch self {
        case .youtube: return ["youtube.com", "youtu.be", "youtube-nocookie.com"]
        case .tiktok: return ["tiktok.com"]
        case .instagram: return ["instagram.com", "instagr.am"]
        case .spotify: return ["spotify.com"]
        case .appleMusic: return ["music.apple.com"]
        case .applePodcasts: return ["podcasts.apple.com"]
        case .appleAppStore: return ["apps.apple.com", "itunes.apple.com"]
        case .x: return ["x.com", "twitter.com", "t.co"]
        case .facebook: return ["facebook.com", "fb.com", "fb.watch"]
        case .threads: return ["threads.com", "threads.net"]
        case .amazon: return ["amazon.com", "amazon.co.uk", "amazon.ca", "amazon.de", "amzn.to"]
        case .netflix: return ["netflix.com"]
        case .imdb: return ["imdb.com"]
        case .letterboxd: return ["letterboxd.com"]
        case .patreon: return ["patreon.com"]
        case .substack: return ["substack.com"]
        case .twitch: return ["twitch.tv"]
        case .vimeo: return ["vimeo.com"]
        case .soundcloud: return ["soundcloud.com"]
        case .bandcamp: return ["bandcamp.com"]
        case .linkedin: return ["linkedin.com"]
        case .github: return ["github.com"]
        }
    }
}

struct LinkServiceBrandMark: View {
    let brand: LinkServiceBrand

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            mark(side: side)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mark(side: CGFloat) -> some View {
        let ink: Color = brand.markUsesDarkInk ? .black : .white
        switch brand {
        case .youtube:
            Image(systemName: "play.fill")
                .font(.system(size: side * 0.42, weight: .bold))
                .foregroundStyle(ink)
                .offset(x: side * 0.03)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .instagram:
            ZStack {
                instagramBackground
                Image(systemName: "camera.fill")
                    .font(.system(size: side * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .tiktok:
            tiktokMark(side: side)
        case .spotify:
            Image(systemName: "music.note.list")
                .font(.system(size: side * 0.46, weight: .semibold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            Image(systemName: brand.systemImage)
                .font(.system(size: side * 0.46, weight: .semibold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var instagramBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.69, blue: 0.19),
                Color(red: 0.88, green: 0.19, blue: 0.42),
                Color(red: 0.58, green: 0.21, blue: 0.86)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    private func tiktokMark(side: CGFloat) -> some View {
        let note = Image(systemName: "music.note")
            .font(.system(size: side * 0.48, weight: .bold))
        return ZStack {
            if side >= 22 {
                note.foregroundStyle(Color(red: 0.15, green: 0.96, blue: 0.93))
                    .offset(x: side * 0.08, y: side * 0.06)
                note.foregroundStyle(Color(red: 1, green: 0.17, blue: 0.33))
                    .offset(x: -side * 0.08, y: -side * 0.04)
            }
            note.foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LinkServiceBrandTile: View {
    let brand: LinkServiceBrand
    var markSide: CGFloat = 34

    var body: some View {
        ZStack {
            tileBackground
            LinkServiceBrandMark(brand: brand)
                .frame(width: markSide, height: markSide)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tileBackground: some View {
        if brand == .instagram {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.69, blue: 0.19),
                    Color(red: 0.88, green: 0.19, blue: 0.42),
                    Color(red: 0.58, green: 0.21, blue: 0.86)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        } else {
            brand.backgroundColor
        }
    }
}
