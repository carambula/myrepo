//
//  OrderReplacementView.swift
//  SpinMin
//
//  UI for ordering replacement components from vendors
//

import SwiftUI
import SwiftData

// MARK: - Order Replacement Sheet

struct OrderReplacementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager
    
    let title: String
    let subtitle: String?
    let orderLinks: [OrderLink]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(title)
                        .titleLarge()
                        .foregroundHeadline()
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .bodyMedium()
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Select a vendor to search for replacement:")
                        .bodySmall()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.top, DesignSystem.Spacing.lg)
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.md)
                
                // Vendor list
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(orderLinks) { link in
                            VendorLinkCard(orderLink: link) {
                                openURL(link.url)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                
                if orderLinks.isEmpty {
                    emptyStateView
                }
            }
            .navigationTitle("Order Replacement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "cart.fill.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Vendors Available")
                .titleLarge()
                .foregroundHeadline()
            
            Text("Try searching online for this component")
                .bodyMedium()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}

// MARK: - Vendor Link Card

struct VendorLinkCard: View {
    let orderLink: OrderLink
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Vendor icon
                Image(systemName: orderLink.vendor.iconName)
                    .font(.system(size: 32))
                    .foregroundStyle(DesignSystem.Color.accent)
                    .frame(width: 60, height: 60)
                    .background(DesignSystem.Color.surfaceElevated)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                
                // Vendor info
                VStack(alignment: .leading, spacing: 4) {
                    Text(orderLink.vendor.displayName)
                        .bodyLarge()
                        .fontWeight(.semibold)
                        .foregroundHeadline()
                    
                    Text(orderLink.vendor.description)
                        .captionMedium()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // External link icon
                Image(systemName: "arrow.up.right.square.fill")
                    .foregroundStyle(DesignSystem.Color.accent)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.surface)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Order Button

struct OrderReplacementButton: View {
    @Environment(\.openURL) private var openURL
    
    @State private var showingOrderSheet = false
    
    let component: ComponentTracking
    let style: OrderButtonStyle
    
    enum OrderButtonStyle {
        case compact
        case prominent
        case icon
    }
    
    var body: some View {
        Button {
            showingOrderSheet = true
        } label: {
            switch style {
            case .compact:
                compactButtonLabel
            case .prominent:
                prominentButtonLabel
            case .icon:
                iconButtonLabel
            }
        }
        .sheet(isPresented: $showingOrderSheet) {
            let links = VendorService.orderLinks(for: component)
            let recommended = VendorService.recommendedVendors(for: VendorService.mapComponentToCategory(component.component))
            let filteredLinks = links.filter { link in
                recommended.contains(link.vendor)
            }
            
            OrderReplacementSheet(
                title: "Order \(component.component.displayName)",
                subtitle: component.displayName,
                orderLinks: filteredLinks.isEmpty ? links : filteredLinks
            )
        }
    }
    
    private var compactButtonLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")
                .font(.system(size: 14))
            Text("Order")
                .labelMedium()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Color.accent)
        .foregroundStyle(.white)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private var prominentButtonLabel: some View {
        HStack {
            Image(systemName: "cart.fill")
            Text("Order Replacement")
                .labelLarge()
            Spacer()
            Image(systemName: "arrow.up.right")
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.accent)
        .foregroundStyle(.white)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var iconButtonLabel: some View {
        Image(systemName: "cart.fill")
            .font(.system(size: 20))
            .foregroundStyle(DesignSystem.Color.accent)
    }
}

// MARK: - Tire Order Button

struct OrderTireButton: View {
    @State private var showingOrderSheet = false
    
    let tire: TireTracking
    let style: OrderReplacementButton.OrderButtonStyle
    
    var body: some View {
        Button {
            showingOrderSheet = true
        } label: {
            switch style {
            case .compact:
                compactButtonLabel
            case .prominent:
                prominentButtonLabel
            case .icon:
                iconButtonLabel
            }
        }
        .sheet(isPresented: $showingOrderSheet) {
            let links = VendorService.orderLinks(for: tire)
            let recommended = VendorService.recommendedVendors(for: .tires)
            let filteredLinks = links.filter { recommended.contains($0.vendor) }
            
            OrderReplacementSheet(
                title: "Order Replacement Tire",
                subtitle: tire.displayName,
                orderLinks: filteredLinks.isEmpty ? links : filteredLinks
            )
        }
    }
    
    private var compactButtonLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")
                .font(.system(size: 14))
            Text("Order")
                .labelMedium()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Color.accent)
        .foregroundStyle(.white)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private var prominentButtonLabel: some View {
        HStack {
            Image(systemName: "cart.fill")
            Text("Order Replacement")
                .labelLarge()
            Spacer()
            Image(systemName: "arrow.up.right")
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.accent)
        .foregroundStyle(.white)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var iconButtonLabel: some View {
        Image(systemName: "cart.fill")
            .font(.system(size: 20))
            .foregroundStyle(DesignSystem.Color.accent)
    }
}

// MARK: - Chain Wax Order Button

struct OrderChainWaxButton: View {
    @State private var showingOrderSheet = false
    
    let lubeType: ChainLubeType
    
    var body: some View {
        Button {
            showingOrderSheet = true
        } label: {
            HStack {
                Image(systemName: "cart.fill")
                Text("Order \(lubeType.displayName)")
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.accent)
            .foregroundStyle(.white)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .sheet(isPresented: $showingOrderSheet) {
            let links = VendorService.orderLinksForChainWax(lubeType: lubeType)
            
            OrderReplacementSheet(
                title: "Order \(lubeType.displayName)",
                subtitle: lubeType.description,
                orderLinks: links
            )
        }
    }
}

#Preview {
    OrderReplacementSheet(
        title: "Order Chain",
        subtitle: "Shimano CN-M9100 12-speed",
        orderLinks: [
            OrderLink(
                vendor: .competitiveCyclist,
                url: URL(string: "https://www.competitivecyclist.com")!,
                displayText: "Search on Competitive Cyclist",
                category: .chains
            ),
            OrderLink(
                vendor: .jensonUSA,
                url: URL(string: "https://www.jensonusa.com")!,
                displayText: "Search on Jenson USA",
                category: .chains
            ),
        ]
    )
    .environment(ThemeManager.shared)
}
