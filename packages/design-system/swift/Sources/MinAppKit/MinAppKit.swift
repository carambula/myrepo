import Foundation

/// MinAppKit - Shared design system tokens for min apps
///
/// This package provides design tokens (spacing, corner radius, opacity, affordance styles)
/// and the shared agent connection surface used by all min apps
/// (WatchedIt, PodLink, YourTube, Cyclismo, SpinMin, fit min).
///
/// ## Tokens Provided
/// - `MinSpacing`: Spacing scale and semantic spacing values
/// - `MinTypography`: Body sizes and line spacing for paragraph / description copy
/// - `MinCornerRadius`: Corner radius tokens for UI elements (follow `MinRadiusStyle`)
/// - `MinRadiusStyle`: Appearance setting that scales rounded corners
/// - `MinOpacity`: Opacity values for various states
/// - `MinAffordanceStyle`: Shared styling for buttons and interactive elements
/// - `minScrollPinnedChrome`: Shared title-mark / account scroll-pin + blur modifier
/// - `edgeSwipeToDismiss`: Omnidirectional edge-swipe dismiss for presented sheets
/// - `sheetHeroSource` / `sheetHeroDestination` / `sheetFromHero` / `sheetHeroOverlayContainer`: system zoom (App Store-style) from a key image into a sheet
///
/// ## Agent kit
/// - `AgentConnectionStore`: hashed tokens and per-app read/write scopes
/// - `AgentJournal`: 7-day undo records and a redacted audit log
/// - `AgentSettingsView`: Account-sheet UI for connecting and revoking agents
public enum MinAppKit {
    /// Current version of MinAppKit
    public static let version = "1.0.0"
}
