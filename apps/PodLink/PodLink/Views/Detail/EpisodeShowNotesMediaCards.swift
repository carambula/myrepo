import SwiftUI

/// Horizontal link cards shown under episode show notes.
struct EpisodeShowNotesMediaCards: View {
    let links: [MediaLink]
    let isLoading: Bool

    var body: some View {
        if isLoading && links.isEmpty {
            ProgressView()
                .scaleEffect(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignSystem.Spacing.xs)
        } else if !links.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    ForEach(links) { link in
                        MediaLinkCardView(link: link)
                    }
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }
}
