//
//  PhysicalPurchaseSheet.swift
//  WatchedIt
//

import SwiftUI

struct PhysicalPurchaseSheet: View {
    let movie: Movie
    let media: PhysicalMedia
    let isOwnedDisc: Bool
    let onOwnedChange: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var groups: [PhysicalPurchaseEditionGroup] {
        PhysicalPurchaseLinkBuilder.groups(for: media, title: movie.title, year: movie.year)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                    header
                    ownToggle
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text(group.headline)
                                .labelMedium()
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Color.textSecondary)

                            VStack(spacing: 0) {
                                ForEach(group.offers) { offer in
                                    Button {
                                        openURL(offer.url)
                                    } label: {
                                        offerRow(offer)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Search \(offer.title) for \(movie.title)")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.top, closeButtonClearance)
                .padding(.bottom, DesignSystem.Spacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DesignSystem.Color.background.ignoresSafeArea())

            Button(action: { dismiss() }) {
                GlassCircleButton(
                    systemImage: DesignSystem.Icon.close,
                    size: .compact,
                    accessibilityLabel: "Close"
                )
            }
            .buttonStyle(.plain)
            .padding(.leading, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var closeButtonClearance: CGFloat {
        DesignSystem.Spacing.lg + GlassControl.compactHeight + DesignSystem.Spacing.md
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(movie.title)
                .titleLarge()
                .foregroundHeadline()
            let meta = metadataLine
            if !meta.isEmpty {
                Text(meta)
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
        }
    }

    private var ownToggle: some View {
        Button {
            onOwnedChange(!isOwnedDisc)
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: isOwnedDisc ? DesignSystem.Icon.discFill : DesignSystem.Icon.disc)
                    .font(.system(size: DesignSystem.IconSize.md))
                    .foregroundColor(isOwnedDisc ? DesignSystem.Color.accent : DesignSystem.Color.textSecondary)
                Text(isOwnedDisc ? "Owned" : "I own this")
                    .bodyMedium()
                    .foregroundColor(DesignSystem.Color.textPrimary)
                Spacer(minLength: DesignSystem.Spacing.sm)
                Image(systemName: isOwnedDisc ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: DesignSystem.IconSize.md))
                    .foregroundColor(isOwnedDisc ? DesignSystem.Color.accent : DesignSystem.Color.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOwnedDisc ? "Owned" : "I own this")
        .accessibilityAddTraits(isOwnedDisc ? [.isSelected] : [])
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let year = movie.year {
            parts.append(String(year))
        }
        parts.append(contentsOf: media.badgeLabels)
        if isOwnedDisc {
            parts.append("Owned")
        }
        return parts.joined(separator: "   ")
    }

    private func offerRow(_ offer: PhysicalPurchaseOffer) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(offer.title)
                .bodyMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            Spacer(minLength: DesignSystem.Spacing.sm)
            Text("Search")
                .captionMedium()
                .foregroundColor(DesignSystem.Color.textSecondary)
            Image(systemName: DesignSystem.Icon.forward)
                .font(.system(size: DesignSystem.IconSize.sm))
                .foregroundColor(DesignSystem.Color.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
    }
}
