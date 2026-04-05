//
//  ToolbarBehaviorSettingsView.swift
//  WatchedIt
//
//  Created by Cursor on 3/7/26.
//

import SwiftUI

struct ToolbarBehaviorSettingsView: View {
    @AppStorage(ToolbarScrollingBehavior.storageKey) private var behaviorRaw: String = ToolbarScrollingBehavior.alwaysVisible.rawValue
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var selectedBehavior: ToolbarScrollingBehavior {
        ToolbarScrollingBehavior(rawValue: behaviorRaw) ?? .alwaysVisible
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Toolbar Behavior")
                        .headlineLarge()
                        .foregroundColor(DesignSystem.Color.textPrimary)
                    
                    Text("Control how the toolbar responds to scrolling on both the main view and search screen.")
                        .bodyMedium()
                        .foregroundColor(DesignSystem.Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DesignSystem.Spacing.md)
                
                // Behavior options
                ForEach(ToolbarScrollingBehavior.allCases, id: \.rawValue) { behavior in
                    behaviorOption(behavior)
                }
                
                // Visual guide
                visualGuide
            }
            .settingsScreenStyle()
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
        .navigationTitle("Toolbar Behavior")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Behavior Option
    
    @ViewBuilder
    private func behaviorOption(_ behavior: ToolbarScrollingBehavior) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                behaviorRaw = behavior.rawValue
            }
        } label: {
            SettingsOptionRow(
                icon: behavior.icon,
                title: behavior.rawValue,
                description: behavior.description,
                isSelected: selectedBehavior == behavior
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Visual Guide
    
    @ViewBuilder
    private var visualGuide: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("How It Works")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                guideItem(
                    icon: "arrow.down",
                    text: "Scroll down to minimize or hide the toolbar",
                    color: .orange
                )
                
                guideItem(
                    icon: "arrow.up",
                    text: "Scroll up to restore the toolbar",
                    color: .blue
                )
                
                guideItem(
                    icon: "hand.tap.fill",
                    text: "Tap minimized toolbar to expand (where applicable)",
                    color: .green
                )
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Color.surface)
            )
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    @ViewBuilder
    private func guideItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .bodyMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        ToolbarBehaviorSettingsView()
    }
}
