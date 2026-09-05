import Foundation

/// MinAppKit - Shared design system tokens for min apps
///
/// This package provides design tokens (spacing, corner radius, opacity, affordance styles)
/// and the shared agent and feedback surfaces used by all min apps
/// (WatchedIt, PodLink, YourTube, Cyclismo, SpinMin, fit min).
///
/// ## Tokens Provided
/// - `MinSpacing`: Spacing scale and semantic spacing values
/// - `MinCornerRadius`: Corner radius tokens for UI elements
/// - `MinOpacity`: Opacity values for various states
/// - `MinAffordanceStyle`: Shared styling for buttons and interactive elements
///
/// ## Agent kit
/// - `AgentConnectionStore`: hashed tokens and per-app read/write scopes
/// - `AgentJournal`: 7-day undo records and a redacted audit log
/// - `AgentSettingsView`: Account-sheet UI for connecting and revoking agents
///
/// ## Feedback
/// - `FeedbackBoardView`: Ideas & Bugs board with votes
/// - `FeedbackSettingsLink`: Account-sheet entry point
public enum MinAppKit {
    /// Current version of MinAppKit
    public static let version = "1.0.0"
}
