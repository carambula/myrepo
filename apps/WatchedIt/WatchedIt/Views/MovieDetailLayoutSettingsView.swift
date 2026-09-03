//
//  MovieDetailLayoutSettingsView.swift
//  WatchedIt
//
//  Created by Cursor on 3/2/26.
//

import SwiftUI

struct MovieDetailLayoutSettingsView: View {
    @AppStorage("movieDetailLayoutStyle") private var layoutStyleRaw: String = MovieDetailLayoutStyle.posterFocus.rawValue
    @AppStorage(MovieDetailLayoutParameters.storageKey) private var parametersData: Data = MovieDetailLayoutParameters().encode()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var parameters: MovieDetailLayoutParameters = MovieDetailLayoutParameters()
    @State private var showPreview = false
    
    private var selectedStyle: MovieDetailLayoutStyle {
        MovieDetailLayoutStyle(rawValue: layoutStyleRaw) ?? .classic
    }
    
    // Sample movie for preview
    private let sampleMovie = Movie(
        id: "sample-preview",
        title: "The Shawshank Redemption",
        year: 1994,
        posterPath: "/9cqNxx0GxF0bflZmeSMuL5tnGzr.jpg",
        backdropPath: "/kXfqcdQKsToO0OUXHcrrNCHDBzO.jpg",
        overview: "Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.",
        mpaaRating: "R",
        genres: ["Drama", "Crime"],
        credits: MovieCredits(
            director: "Frank Darabont",
            cast: [
                CastMember(id: 1, name: "Tim Robbins"),
                CastMember(id: 2, name: "Morgan Freeman")
            ]
        ),
        isRewatched: false,
        isListened: false,
        isSaved: false
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Style selector
                styleSelector
                
                // Preview button
                previewButton
                
                // Parameters for selected style
                parametersSection
            }
            .settingsScreenStyle()
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
        .navigationTitle("Movie Details Layout")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPreview) {
            NavigationView {
                MovieDetailView(movie: sampleMovie, presentationSource: .preview)
            }
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            parameters = MovieDetailLayoutParameters.decode(from: parametersData)
        }
        .task(id: parametersPersistenceKey) {
            saveParameters()
        }
    }
    
    // MARK: - Style Selector
    
    @ViewBuilder
    private var styleSelector: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Layout Style")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            
            ForEach(MovieDetailLayoutStyle.allCases, id: \.rawValue) { style in
                Button {
                    layoutStyleRaw = style.rawValue
                } label: {
                    SettingsOptionRow(
                        icon: style.icon,
                        title: style.rawValue,
                        description: style.description,
                        isSelected: selectedStyle == style
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Preview Button
    
    @ViewBuilder
    private var previewButton: some View {
        Button {
            showPreview = true
        } label: {
            HStack {
                Image(systemName: "eye.fill")
                    .font(DesignSystem.Typography.headlineSmall)
                
                Text("Preview Layout")
                    .headlineSmall()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Color.accent)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Parameters Section
    
    @ViewBuilder
    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Layout Parameters")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)

            LayoutParameterSegmentedSelector(
                title: "Action Bar Layout",
                description: "Choose whether the action buttons are centered or left-aligned with the content below",
                selection: Binding(
                    get: { parameters.actionBarLayout.rawValue },
                    set: { raw in
                        parameters.actionBarLayout = MovieDetailActionBarLayout(rawValue: raw) ?? .centered
                    }
                ),
                options: [
                    ("centered", "Centered"),
                    ("leftAligned", "Left Aligned")
                ]
            )
            
            switch selectedStyle {
            case .classic:
                classicParameters
            case .compact:
                compactParameters
            case .split:
                splitParameters
            case .posterFocus:
                posterFocusParameters
            case .cinematic:
                cinematicParameters
            case .cinematicWithTransition:
                cinematicParameters
            }
        }
    }
    
    // MARK: - Classic Parameters
    
    @ViewBuilder
    private var classicParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            LayoutParameterSlider(
                title: "Backdrop Height",
                value: $parameters.classicBackdropHeight,
                range: 150...400,
                description: "Height of the backdrop image at the top"
            )
            
            LayoutParameterSlider(
                title: "Poster Height",
                value: $parameters.classicPosterHeight,
                range: 250...500,
                description: "Height when showing poster instead of backdrop"
            )
        }
    }
    
    // MARK: - Compact Parameters
    
    @ViewBuilder
    private var compactParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            LayoutParameterSlider(
                title: "Poster Width",
                value: $parameters.compactPosterWidth,
                range: 80...180,
                description: "Width of the poster on the left side"
            )
            
            LayoutParameterSlider(
                title: "Poster Height",
                value: $parameters.compactPosterHeight,
                range: 120...270,
                description: "Height of the poster on the left side"
            )
            
            LayoutParameterSlider(
                title: "Blur Radius",
                value: $parameters.compactBlurRadius,
                range: 5...40,
                description: "Amount of blur on the backdrop background"
            )
        }
    }
    
    // MARK: - Split Parameters
    
    @ViewBuilder
    private var splitParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            LayoutParameterSlider(
                title: "Poster Width",
                value: $parameters.splitPosterWidth,
                range: 100...200,
                description: "Width of the poster on the left"
            )
            
            LayoutParameterSlider(
                title: "Backdrop Opacity",
                value: $parameters.splitBackdropOpacity,
                range: 0.3...1.0,
                description: "Transparency of the backdrop on the right"
            )
            
            LayoutParameterSlider(
                title: "Title Overlap",
                value: $parameters.splitTitleOverlap,
                range: 0...80,
                description: "How far the title overlaps the images"
            )
        }
    }
    
    // MARK: - Poster Focus Parameters
    
    @ViewBuilder
    private var posterFocusParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            LayoutParameterToggle(
                title: "Full Bleed Top Poster",
                isOn: $parameters.posterFocusFullBleed,
                description: "Make poster fill the full width at the top of the detail sheet"
            )

            LayoutParameterSlider(
                title: "Poster Height",
                value: $parameters.posterFocusHeight,
                range: 225...450,
                description: "Height of the centered poster"
            )

            if parameters.posterFocusFullBleed {
                LayoutParameterSegmentedSelector(
                    title: "Action Bar Position",
                    description: "Choose whether actions sit below poster or overlap its bottom edge",
                    selection: Binding(
                        get: { parameters.posterFocusActionBarPosition.rawValue },
                        set: { raw in
                            parameters.posterFocusActionBarPosition = MovieDetailActionBarPosition(rawValue: raw) ?? .below
                        }
                    ),
                    options: [
                        ("below", "Below"),
                        ("overlapping", "Overlapping")
                    ]
                )

                LayoutParameterSlider(
                    title: "Poster Fade",
                    value: $parameters.posterFocusFadePercentage,
                    range: 0...25,
                    description: "Fade from poster bottom upward (% of poster height)"
                )
            } else {
                LayoutParameterSlider(
                    title: "Poster Width",
                    value: $parameters.posterFocusWidth,
                    range: 150...300,
                    description: "Width of the centered poster"
                )

                LayoutParameterSlider(
                    title: "Shadow Radius",
                    value: $parameters.posterFocusShadowRadius,
                    range: 5...40,
                    description: "Size of the drop shadow around poster"
                )
            }
        }
    }
    
    // MARK: - Cinematic Parameters
    
    @ViewBuilder
    private var cinematicParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            LayoutParameterSlider(
                title: "Backdrop Height",
                value: $parameters.cinematicBackdropHeight,
                range: 250...450,
                description: "Height of the full-width backdrop"
            )
            
            LayoutParameterSlider(
                title: "Poster Scale",
                value: $parameters.cinematicPosterScale,
                range: 0.5...1.2,
                description: "Size of the floating poster card (1.0 = normal)"
            )
            
            LayoutParameterSlider(
                title: "Overlay Opacity",
                value: $parameters.cinematicOverlayOpacity,
                range: 0.1...0.7,
                description: "Darkness of the gradient overlay on backdrop"
            )
        }
    }
    
    // MARK: - Helper Methods

    private var parametersPersistenceKey: String {
        [
            parameters.classicBackdropHeight,
            parameters.classicPosterHeight,
            parameters.compactPosterWidth,
            parameters.compactPosterHeight,
            parameters.compactBlurRadius,
            parameters.splitPosterWidth,
            parameters.splitBackdropOpacity,
            parameters.splitTitleOverlap,
            parameters.posterFocusWidth,
            parameters.posterFocusHeight,
            parameters.posterFocusShadowRadius,
            parameters.actionBarLayout == .leftAligned ? 1 : 0,
            parameters.posterFocusFullBleed ? 1 : 0,
            parameters.posterFocusActionBarPosition == .overlapping ? 1 : 0,
            parameters.posterFocusFadePercentage,
            parameters.cinematicBackdropHeight,
            parameters.cinematicPosterScale,
            parameters.cinematicOverlayOpacity
        ]
        .map { String(format: "%.4f", $0) }
        .joined(separator: "|")
    }
    
    private func saveParameters() {
        parametersData = parameters.encode()
    }
}

// MARK: - Layout Parameter Slider Component

struct LayoutParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .bodyMedium()
                    .foregroundColor(DesignSystem.Color.textPrimary)
                
                Spacer()
                
                Text(String(format: "%.0f", value))
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.accent)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range)
                .tint(DesignSystem.Color.accent)
            
            Text(description)
                .bodySmall()
                .foregroundColor(DesignSystem.Color.textSecondary)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.surface)
        )
    }
}

struct LayoutParameterToggle: View {
    let title: String
    @Binding var isOn: Bool
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .bodyMedium()
                    .foregroundColor(DesignSystem.Color.textPrimary)
            }
            .tint(DesignSystem.Color.accent)

            Text(description)
                .bodySmall()
                .foregroundColor(DesignSystem.Color.textSecondary)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.surface)
        )
    }
}

struct LayoutParameterSegmentedSelector: View {
    let title: String
    let description: String
    @Binding var selection: String
    let options: [(id: String, label: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .bodyMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.id) { option in
                    Text(option.label).tag(option.id)
                }
            }
            .pickerStyle(.segmented)

            Text(description)
                .bodySmall()
                .foregroundColor(DesignSystem.Color.textSecondary)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.surface)
        )
    }
}
