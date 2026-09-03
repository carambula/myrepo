//
//  MovieDetailLayoutStyles.swift
//  WatchedIt
//
//  Created by Cursor on 3/2/26.
//

import SwiftUI

// MARK: - Movie Detail Layout Style

enum MovieDetailLayoutStyle: String, CaseIterable {
    case classic = "Classic"
    case compact = "Compact"
    case split = "Split"
    case posterFocus = "Poster Focus"
    case cinematic = "Cinematic"
    case cinematicWithTransition = "Cinematic with Transition"
    
    var description: String {
        switch self {
        case .classic:
            return "Full-width backdrop or poster at top"
        case .compact:
            return "Poster on left with blurred backdrop background"
        case .split:
            return "Poster and backdrop side-by-side with overlapping title"
        case .posterFocus:
            return "Large centered poster, no backdrop, minimal design"
        case .cinematic:
            return "Full backdrop with floating poster card overlay"
        case .cinematicWithTransition:
            return "Cinematic layout with poster jump-in from list/search"
        }
    }
    
    var icon: String {
        switch self {
        case .classic:
            return "rectangle.fill"
        case .compact:
            return "rectangle.lefthalf.filled"
        case .split:
            return "rectangle.split.2x1"
        case .posterFocus:
            return "photo"
        case .cinematic:
            return "film"
        case .cinematicWithTransition:
            return "sparkles.tv"
        }
    }
}

enum MovieDetailTransitionSource: String {
    case mainList
    case searchList
    case collections
    case preview
    case unknown

    var initialPosterOffset: CGSize {
        switch self {
        case .mainList:
            return CGSize(width: 0, height: 230)
        case .searchList:
            return CGSize(width: 0, height: 170)
        case .collections:
            return CGSize(width: 0, height: 210)
        case .preview:
            return CGSize(width: 0, height: 130)
        case .unknown:
            return CGSize(width: 0, height: 160)
        }
    }

    var initialPosterScale: CGFloat {
        switch self {
        case .mainList, .searchList:
            return 0.36
        case .collections:
            return 0.55
        case .preview, .unknown:
            return 0.42
        }
    }
}

enum MovieDetailActionBarPosition: String {
    case below
    case overlapping
}

enum MovieDetailActionBarLayout: String {
    case centered
    case leftAligned
}

// MARK: - Movie Detail Layout Parameters

struct MovieDetailLayoutParameters {
    // Classic parameters
    var classicBackdropHeight: Double = 250
    var classicPosterHeight: Double = 400
    
    // Compact parameters
    var compactPosterWidth: Double = 120
    var compactPosterHeight: Double = 180
    var compactBlurRadius: Double = 20
    
    // Split parameters
    var splitPosterWidth: Double = 140
    var splitBackdropOpacity: Double = 0.8
    var splitTitleOverlap: Double = 40
    
    // Poster Focus parameters
    var posterFocusWidth: Double = 220
    var posterFocusHeight: Double = 330
    var posterFocusShadowRadius: Double = 20
    var actionBarLayout: MovieDetailActionBarLayout = .leftAligned
    var posterFocusFullBleed: Bool = true
    var posterFocusActionBarPosition: MovieDetailActionBarPosition = .below
    var posterFocusFadePercentage: Double = 0
    
    // Cinematic parameters
    var cinematicBackdropHeight: Double = 350
    var cinematicPosterScale: Double = 0.75
    var cinematicOverlayOpacity: Double = 0.3
    
    static var storageKey: String { "movieDetailLayoutParameters" }
    
    // Encode/decode for AppStorage
    func encode() -> Data {
        let dict: [String: Double] = [
            "classicBackdropHeight": classicBackdropHeight,
            "classicPosterHeight": classicPosterHeight,
            "compactPosterWidth": compactPosterWidth,
            "compactPosterHeight": compactPosterHeight,
            "compactBlurRadius": compactBlurRadius,
            "splitPosterWidth": splitPosterWidth,
            "splitBackdropOpacity": splitBackdropOpacity,
            "splitTitleOverlap": splitTitleOverlap,
            "posterFocusWidth": posterFocusWidth,
            "posterFocusHeight": posterFocusHeight,
            "posterFocusShadowRadius": posterFocusShadowRadius,
            "actionBarLayout": actionBarLayout == .leftAligned ? 1 : 0,
            "posterFocusFullBleed": posterFocusFullBleed ? 1 : 0,
            "posterFocusActionBarPosition": posterFocusActionBarPosition == .overlapping ? 1 : 0,
            "posterFocusFadePercentage": posterFocusFadePercentage,
            "cinematicBackdropHeight": cinematicBackdropHeight,
            "cinematicPosterScale": cinematicPosterScale,
            "cinematicOverlayOpacity": cinematicOverlayOpacity
        ]
        return (try? JSONEncoder().encode(dict)) ?? Data()
    }
    
    static func decode(from data: Data) -> MovieDetailLayoutParameters {
        guard let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return MovieDetailLayoutParameters()
        }
        
        var params = MovieDetailLayoutParameters()
        params.classicBackdropHeight = dict["classicBackdropHeight"] ?? 250
        params.classicPosterHeight = dict["classicPosterHeight"] ?? 400
        params.compactPosterWidth = dict["compactPosterWidth"] ?? 120
        params.compactPosterHeight = dict["compactPosterHeight"] ?? 180
        params.compactBlurRadius = dict["compactBlurRadius"] ?? 20
        params.splitPosterWidth = dict["splitPosterWidth"] ?? 140
        params.splitBackdropOpacity = dict["splitBackdropOpacity"] ?? 0.8
        params.splitTitleOverlap = dict["splitTitleOverlap"] ?? 40
        params.posterFocusWidth = dict["posterFocusWidth"] ?? 220
        params.posterFocusHeight = dict["posterFocusHeight"] ?? 330
        params.posterFocusShadowRadius = dict["posterFocusShadowRadius"] ?? 20
        params.actionBarLayout = (dict["actionBarLayout"] ?? 0) > 0.5 ? .leftAligned : .centered
        params.posterFocusFullBleed = (dict["posterFocusFullBleed"] ?? 0) > 0.5
        params.posterFocusActionBarPosition = (dict["posterFocusActionBarPosition"] ?? 0) > 0.5 ? .overlapping : .below
        params.posterFocusFadePercentage = min(max(dict["posterFocusFadePercentage"] ?? 0, 0), 25)
        params.cinematicBackdropHeight = dict["cinematicBackdropHeight"] ?? 350
        params.cinematicPosterScale = dict["cinematicPosterScale"] ?? 0.75
        params.cinematicOverlayOpacity = dict["cinematicOverlayOpacity"] ?? 0.3
        return params
    }
}

// MARK: - Movie Detail Header Layout

struct MovieDetailHeaderLayout: View {
    let movie: Movie
    let style: MovieDetailLayoutStyle
    let parameters: MovieDetailLayoutParameters
    var transitionSource: MovieDetailTransitionSource = .unknown
    
    var body: some View {
        Group {
            switch style {
            case .classic:
                ClassicHeaderLayout(movie: movie, parameters: parameters)
            case .compact:
                CompactHeaderLayout(movie: movie, parameters: parameters)
            case .split:
                SplitHeaderLayout(movie: movie, parameters: parameters)
            case .posterFocus:
                PosterFocusHeaderLayout(movie: movie, parameters: parameters)
            case .cinematic:
                CinematicHeaderLayout(movie: movie, parameters: parameters)
            case .cinematicWithTransition:
                CinematicHeaderLayout(
                    movie: movie,
                    parameters: parameters,
                    enablePosterTransition: true,
                    transitionSource: transitionSource
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - Classic Header Layout

struct ClassicHeaderLayout: View {
    let movie: Movie
    let parameters: MovieDetailLayoutParameters

    private var headerHeight: CGFloat {
        if let backdropPath = movie.backdropPath, !backdropPath.isEmpty {
            return parameters.classicBackdropHeight
        }
        return parameters.classicPosterHeight
    }
    
    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = max(geometry.size.width, 1)

            if let backdropPath = movie.backdropPath, !backdropPath.isEmpty {
                let backdropURL = backdropPath.hasPrefix("http") ? backdropPath : MovieDataService.shared.getBackdropURL(path: backdropPath) ?? backdropPath
                if let url = URL(string: backdropURL), url.scheme != nil {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(DesignSystem.Color.surface)
                            .overlay(ProgressView())
                    }
                    .frame(width: viewportWidth, height: parameters.classicBackdropHeight)
                    .clipped()
                    .padding(.top, -20)
                    .ignoresSafeArea(edges: .top)
                }
            } else if let posterPath = movie.posterPath, !posterPath.isEmpty {
                let posterURL = posterPath.hasPrefix("http") ? posterPath : MovieDataService.shared.getLargePosterURL(path: posterPath) ?? posterPath
                if let url = URL(string: posterURL), url.scheme != nil {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(DesignSystem.Color.surface)
                            .overlay(ProgressView())
                    }
                    .frame(width: viewportWidth, height: parameters.classicPosterHeight)
                    .clipped()
                    .padding(.top, -60)
                    .ignoresSafeArea(edges: .top)
                }
            }
        }
        .frame(height: headerHeight)
    }
}

// MARK: - Compact Header Layout

struct CompactHeaderLayout: View {
    let movie: Movie
    let parameters: MovieDetailLayoutParameters
    
    var body: some View {
        ZStack {
            // Blurred backdrop background
            if let backdropPath = movie.backdropPath, !backdropPath.isEmpty {
                let backdropURL = backdropPath.hasPrefix("http") ? backdropPath : MovieDataService.shared.getBackdropURL(path: backdropPath) ?? backdropPath
                if let url = URL(string: backdropURL), url.scheme != nil {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(DesignSystem.Color.surface)
                    }
                    .frame(height: parameters.compactPosterHeight + 40)
                    .blur(radius: parameters.compactBlurRadius)
                    .overlay(
                        Rectangle()
                            .fill(DesignSystem.Color.background.opacity(0.7))
                    )
                    .clipped()
                }
            }
            
            // Poster on left
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                if let posterPath = movie.posterPath, !posterPath.isEmpty {
                    let posterURL = posterPath.hasPrefix("http") ? posterPath : MovieDataService.shared.getLargePosterURL(path: posterPath) ?? posterPath
                    if let url = URL(string: posterURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(DesignSystem.Color.surface)
                        }
                        .frame(width: parameters.compactPosterWidth, height: parameters.compactPosterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(height: parameters.compactPosterHeight + 40)
    }
}

// MARK: - Split Header Layout

struct SplitHeaderLayout: View {
    let movie: Movie
    let parameters: MovieDetailLayoutParameters
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Poster on left
                if let posterPath = movie.posterPath, !posterPath.isEmpty {
                    let posterURL = posterPath.hasPrefix("http") ? posterPath : MovieDataService.shared.getLargePosterURL(path: posterPath) ?? posterPath
                    if let url = URL(string: posterURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(DesignSystem.Color.surface)
                        }
                        .frame(width: parameters.splitPosterWidth)
                        .clipped()
                    }
                }
                
                // Backdrop on right
                if let backdropPath = movie.backdropPath, !backdropPath.isEmpty {
                    let backdropURL = backdropPath.hasPrefix("http") ? backdropPath : MovieDataService.shared.getBackdropURL(path: backdropPath) ?? backdropPath
                    if let url = URL(string: backdropURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(DesignSystem.Color.surface)
                        }
                        .opacity(parameters.splitBackdropOpacity)
                        .clipped()
                    }
                }
            }
            .frame(height: 280)
        }
        .frame(height: 280)
        .padding(.top, -20)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Poster Focus Header Layout

struct PosterFocusHeaderLayout: View {
    let movie: Movie
    let parameters: MovieDetailLayoutParameters
    
    var body: some View {
        if parameters.posterFocusFullBleed {
            VStack(spacing: 0) {
                if let posterPath = movie.posterPath, !posterPath.isEmpty {
                    let posterURL = posterPath.hasPrefix("http") ? posterPath : MovieDataService.shared.getLargePosterURL(path: posterPath) ?? posterPath
                    if let url = URL(string: posterURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(DesignSystem.Color.surface)
                                .overlay(ProgressView())
                                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .bottom) {
                            if parameters.posterFocusFadePercentage > 0 {
                                GeometryReader { proxy in
                                    let fadeHeight = proxy.size.height * CGFloat(parameters.posterFocusFadePercentage / 100)
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.clear,
                                            DesignSystem.Color.background
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: fadeHeight)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                }
                            }
                        }
                        .ignoresSafeArea(edges: .top)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(DesignSystem.Color.background)
        } else {
            VStack(spacing: 0) {
                if let posterPath = movie.posterPath, !posterPath.isEmpty {
                    let posterURL = posterPath.hasPrefix("http") ? posterPath : MovieDataService.shared.getLargePosterURL(path: posterPath) ?? posterPath
                    if let url = URL(string: posterURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(DesignSystem.Color.surface)
                                .overlay(ProgressView())
                        }
                        .frame(width: parameters.posterFocusWidth, height: parameters.posterFocusHeight)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .shadow(color: .black.opacity(0.4), radius: parameters.posterFocusShadowRadius, x: 0, y: 10)
                        .padding(.top, DesignSystem.Spacing.xl)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    }
                }
            }
            .frame(height: parameters.posterFocusHeight)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.Color.background)
        }
    }
}

// MARK: - Cinematic Header Layout

struct CinematicHeaderLayout: View {
    let movie: Movie
    let parameters: MovieDetailLayoutParameters
    var enablePosterTransition: Bool = false
    var transitionSource: MovieDetailTransitionSource = .unknown
    @State private var hasCompletedTransition = false
    
    private var posterWidth: CGFloat {
        140 * parameters.cinematicPosterScale
    }
    
    private var posterHeight: CGFloat {
        210 * parameters.cinematicPosterScale
    }
    
    private var posterVerticalOffset: CGFloat {
        40
    }
    
    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = max(geometry.size.width, 1)

            ZStack(alignment: .bottom) {
                // Full-width backdrop constrained to viewport width.
                if let backdropPath = movie.backdropPath, !backdropPath.isEmpty {
                    let backdropURL = backdropPath.hasPrefix("http") ? backdropPath : MovieDataService.shared.getBackdropURL(path: backdropPath) ?? backdropPath
                    if let url = URL(string: backdropURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(DesignSystem.Color.surface)
                                .overlay(ProgressView())
                        }
                        .frame(width: viewportWidth, height: parameters.cinematicBackdropHeight)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    DesignSystem.Color.background.opacity(parameters.cinematicOverlayOpacity),
                                    DesignSystem.Color.background
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                
                // Floating poster card
                if let posterPath = movie.posterPath, !posterPath.isEmpty {
                    let posterURL = posterPath.hasPrefix("http") ? posterPath : MovieDataService.shared.getLargePosterURL(path: posterPath) ?? posterPath
                    if let url = URL(string: posterURL), url.scheme != nil {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(DesignSystem.Color.surface)
                        }
                        .frame(width: posterWidth, height: posterHeight)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                        .scaleEffect(currentPosterScale)
                        .opacity(currentPosterOpacity)
                        .offset(
                            x: currentPosterOffset.width,
                            y: posterVerticalOffset + currentPosterOffset.height
                        )
                        .onAppear {
                            guard enablePosterTransition else { return }
                            hasCompletedTransition = false
                            withAnimation(.spring(response: 0.48, dampingFraction: 0.84, blendDuration: 0.12)) {
                                hasCompletedTransition = true
                            }
                        }
                    }
                }
            }
            .frame(width: viewportWidth, height: parameters.cinematicBackdropHeight + posterVerticalOffset)
            .clipped()
        }
        .frame(height: parameters.cinematicBackdropHeight + posterVerticalOffset)
        .clipped()
        .padding(.top, -20)
        .ignoresSafeArea(edges: .top)
    }

    private var currentPosterOffset: CGSize {
        guard enablePosterTransition, !hasCompletedTransition else { return .zero }
        return transitionSource.initialPosterOffset
    }

    private var currentPosterScale: CGFloat {
        guard enablePosterTransition, !hasCompletedTransition else { return 1.0 }
        return transitionSource.initialPosterScale
    }

    private var currentPosterOpacity: Double {
        guard enablePosterTransition, !hasCompletedTransition else { return 1.0 }
        return 0.72
    }
}
