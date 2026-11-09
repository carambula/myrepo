import CoreGraphics
import Foundation

/// Shared math for omnidirectional edge-swipe-to-dismiss.
/// Mirrors `packages/design-system/src/components/edgeSwipeToDismiss.js`.
public struct EdgeSwipeToDismissConfiguration {
    public var sideInset: CGFloat
    public var topInset: CGFloat
    public var bottomInset: CGFloat
    public var dismissDistance: CGFloat
    public var velocityThreshold: CGFloat
    public var minFlingDistance: CGFloat
    public var minScale: CGFloat
    public var includesBottomEdge: Bool

    public init(
        sideInset: CGFloat = 24,
        topInset: CGFloat = 44,
        bottomInset: CGFloat = 24,
        dismissDistance: CGFloat = 120,
        velocityThreshold: CGFloat = 900,
        minFlingDistance: CGFloat = 48,
        minScale: CGFloat = 0.92,
        includesBottomEdge: Bool = false
    ) {
        self.sideInset = sideInset
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.dismissDistance = dismissDistance
        self.velocityThreshold = velocityThreshold
        self.minFlingDistance = minFlingDistance
        self.minScale = minScale
        self.includesBottomEdge = includesBottomEdge
    }

    public static let `default` = EdgeSwipeToDismissConfiguration()
}

public enum EdgeSwipeToDismiss {
    public static func isOnSheetEdge(
        _ point: CGPoint,
        in size: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> Bool {
        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return false }
        let x = point.x
        let y = point.y
        let onLeft = x >= 0 && x <= configuration.sideInset
        let onRight = x >= width - configuration.sideInset && x <= width
        let onTop = y >= 0 && y <= configuration.topInset
        let onBottom = configuration.includesBottomEdge
            && y >= height - configuration.bottomInset
            && y <= height
        return onLeft || onRight || onTop || onBottom
    }

    public static func distance(_ translation: CGSize) -> CGFloat {
        hypot(translation.width, translation.height)
    }

    public static func progress(
        _ translation: CGSize,
        dismissDistance: CGFloat = EdgeSwipeToDismissConfiguration.default.dismissDistance
    ) -> CGFloat {
        guard dismissDistance > 0 else { return 0 }
        return min(1, distance(translation) / dismissDistance)
    }

    public static func scale(
        progress: CGFloat,
        minScale: CGFloat = EdgeSwipeToDismissConfiguration.default.minScale
    ) -> CGFloat {
        let clamped = min(1, max(0, progress))
        return 1 - (1 - minScale) * clamped
    }

    public static func backdropOpacity(progress: CGFloat) -> CGFloat {
        max(0, 1 - min(1, max(0, progress)))
    }

    public static func shouldDismiss(
        translation: CGSize,
        velocity: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> Bool {
        let dist = distance(translation)
        if dist >= configuration.dismissDistance { return true }
        if dist < configuration.minFlingDistance { return false }
        let speed = hypot(velocity.width, velocity.height)
        guard speed >= configuration.velocityThreshold else { return false }
        return translation.width * velocity.width + translation.height * velocity.height > 0
    }

    public static func dismissTranslation(
        _ translation: CGSize,
        sheetSize: CGSize
    ) -> CGSize {
        let dist = distance(translation)
        let travel = max(hypot(sheetSize.width, sheetSize.height), 1)
        guard dist >= 1 else {
            return CGSize(width: 0, height: travel)
        }
        let scale = travel / dist
        return CGSize(width: translation.width * scale, height: translation.height * scale)
    }

    public static func transform(
        translation: CGSize,
        progress: CGFloat,
        configuration: EdgeSwipeToDismissConfiguration = .default,
        dismissing: Bool = false,
        dismissTranslation: CGSize = .zero
    ) -> CGAffineTransform {
        let x = dismissing ? dismissTranslation.width : translation.width
        let y = dismissing ? dismissTranslation.height : translation.height
        let scale = dismissing
            ? configuration.minScale
            : self.scale(progress: progress, minScale: configuration.minScale)
        return CGAffineTransform(translationX: x, y: y).scaledBy(x: scale, y: scale)
    }
}
