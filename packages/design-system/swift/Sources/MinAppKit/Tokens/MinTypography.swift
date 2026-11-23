import SwiftUI

/// Body type styles for the min apps.
///
/// Paragraph copy (movie overviews, podcast show notes, video/channel summaries)
/// uses **one** size — `bodyCopySize` — with open line spacing. Do not set that
/// kind of text in `bodySmall`, caption, or an ad-hoc point size.
public enum MinTypography {
    /// iOS body / theme `bodyFont`.
    public static let bodyLargeSize: CGFloat = 17

    /// Canonical paragraph / description size.
    public static let bodyCopySize: CGFloat = 16

    /// Same size as `bodyCopySize`. Use for UI labels at body scale; prefer
    /// `bodyCopy()` / `minBodyCopy()` when the text is a description.
    public static let bodyMediumSize: CGFloat = bodyCopySize

    /// Compact UI chrome (metadata, accessory labels). Not for descriptions.
    public static let bodySmallSize: CGFloat = 15

    /// CSS / web line-height for body copy.
    public static let bodyLineHeightMultiple: CGFloat = 1.65

    /// Extra SwiftUI `.lineSpacing` for multi-line body copy.
    /// San Francisco already includes ~1.2 leading; 8pt extra on 16pt copy
    /// reads near the 1.65 CSS target instead of the previous 4pt (too tight).
    public static let bodyLineSpacing: CGFloat = 8
}

extension View {
    /// Open leading for paragraph / description copy.
    /// Apply after the body font (`bodyMedium` / `bodyCopy`).
    public func minBodyCopy() -> some View {
        lineSpacing(MinTypography.bodyLineSpacing)
    }
}
