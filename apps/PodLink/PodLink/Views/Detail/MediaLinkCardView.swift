import SwiftUI

struct MediaLinkCardView: View {
    let link: MediaLink

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openURL) private var openURL

    @State private var preview = LinkCardPreview()

    private static let columnWidth: CGFloat = 120
    private static let imageHeight: CGFloat = 72
    private static let badgeSide: CGFloat = 20

    private var photographURL: URL? {
        link.imageURL ?? preview.photographURL
    }

    private var brand: LinkServiceBrand? {
        preview.brand ?? LinkServiceBrand.matching(link.destinationURL)
    }

    private var domainLine: String {
        let domain = link.displayDomain
        if !domain.isEmpty { return domain }
        return link.destinationURL.host ?? ""
    }

    var body: some View {
        Button {
            if let appScheme = link.appSchemeURL, UIApplication.shared.canOpenURL(appScheme) {
                openURL(appScheme)
            } else {
                openURL(link.destinationURL)
            }
        } label: {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                previewImage

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.title)
                        .font(DesignSystem.Typography.labelMedium())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: Self.columnWidth, alignment: .leading)

                    if !domainLine.isEmpty {
                        Text(domainLine)
                            .font(DesignSystem.Typography.captionSmall())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: Self.columnWidth, alignment: .leading)
                    }
                }
            }
            .frame(width: Self.columnWidth, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .task(id: link.id) {
            let resolved = await LinkPreviewImageResolver.shared.preview(for: link.destinationURL)
            await MainActor.run {
                preview = resolved
            }
        }
    }

    private var previewImage: some View {
        ZStack(alignment: .bottomTrailing) {
            artwork

            if photographURL != nil, brand != .instagram {
                serviceBadge
                    .padding(DesignSystem.Spacing.xs)
            }
        }
        .frame(width: Self.columnWidth, height: Self.imageHeight, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
    }

    @ViewBuilder
    private var artwork: some View {
        if let photographURL {
            AsyncCachedImage(url: photographURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                fallbackArtwork
            }
            .frame(width: Self.columnWidth, height: Self.imageHeight)
            .clipped()
        } else {
            fallbackArtwork
        }
    }

    @ViewBuilder
    private var fallbackArtwork: some View {
        if let brand {
            LinkServiceBrandTile(brand: brand, markSide: 34)
        } else {
            iconPlaceholder
        }
    }

    @ViewBuilder
    private var serviceBadge: some View {
        if let brand {
            LinkServiceBrandTile(brand: brand, markSide: 12)
                .frame(width: Self.badgeSide, height: Self.badgeSide)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
        } else if let badgeURL = preview.badgeURL {
            AsyncCachedImage(url: badgeURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(3)
            } placeholder: {
                Color.clear
            }
            .frame(width: Self.badgeSide, height: Self.badgeSide)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var iconPlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
            .fill(themeManager.currentTheme.accentColor.opacity(0.15))
            .overlay {
                Image(systemName: link.type.systemImage)
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.currentTheme.accentColor)
            }
    }
}
