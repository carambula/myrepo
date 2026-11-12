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
    public var minFlingSpeed: CGFloat
    public var maxFlingSpeed: CGFloat
    public var minFlingDuration: TimeInterval
    public var maxFlingDuration: TimeInterval
    /// Higher = closer to 1:1. ~720 lets an 80pt pull move ~71pt.
    public var bottomSwipeStiffness: CGFloat

    public init(
        sideInset: CGFloat = 24,
        topInset: CGFloat = 44,
        bottomInset: CGFloat = 24,
        dismissDistance: CGFloat = 120,
        velocityThreshold: CGFloat = 900,
        minFlingDistance: CGFloat = 48,
        minScale: CGFloat = 0.92,
        includesBottomEdge: Bool = false,
        minFlingSpeed: CGFloat = 1100,
        maxFlingSpeed: CGFloat = 2800,
        minFlingDuration: TimeInterval = 0.18,
        maxFlingDuration: TimeInterval = 0.42,
        bottomSwipeStiffness: CGFloat = 720
    ) {
        self.sideInset = sideInset
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.dismissDistance = dismissDistance
        self.velocityThreshold = velocityThreshold
        self.minFlingDistance = minFlingDistance
        self.minScale = minScale
        self.includesBottomEdge = includesBottomEdge
        self.minFlingSpeed = minFlingSpeed
        self.maxFlingSpeed = maxFlingSpeed
        self.minFlingDuration = minFlingDuration
        self.maxFlingDuration = maxFlingDuration
        self.bottomSwipeStiffness = bottomSwipeStiffness
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

    public enum Activation: Equatable {
        case edge
        case topOverscroll
        case bottomOverscroll
    }

    /// Once content cannot scroll farther, remaining movement can take over the sheet.
    public static func scrollLimitActivation(
        translation: CGSize,
        atTop: Bool,
        atBottom: Bool
    ) -> Activation? {
        guard abs(translation.height) >= abs(translation.width) else { return nil }
        if atTop, translation.height > 0 { return .topOverscroll }
        if atBottom, translation.height < 0 { return .bottomOverscroll }
        return nil
    }

    /// Mild resistance so the sheet lags the finger a little.
    public static func resistOffset(
        _ offset: CGFloat,
        stiffness: CGFloat = EdgeSwipeToDismissConfiguration.default.bottomSwipeStiffness
    ) -> CGFloat {
        guard offset != 0 else { return 0 }
        let s = max(stiffness, 1)
        return offset / (1 + abs(offset) / s)
    }

    /// Bottom-overscroll follow is resisted (especially upward). Edge and
    /// top-overscroll stay 1:1 with the finger.
    public static func visualTranslation(
        _ translation: CGSize,
        activation: Activation,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> CGSize {
        guard activation == .bottomOverscroll else { return translation }
        let stiffness = configuration.bottomSwipeStiffness
        let x = resistOffset(translation.width, stiffness: stiffness)
        let y = translation.height < 0
            ? resistOffset(translation.height, stiffness: stiffness)
            : translation.height
        return CGSize(width: x, height: y)
    }

    public static func isScrollAtTop(_ offsetY: CGFloat, insetTop: CGFloat, epsilon: CGFloat = 1.5) -> Bool {
        offsetY <= -insetTop + epsilon
    }

    public static func isScrollAtBottom(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        boundsHeight: CGFloat,
        insetTop: CGFloat,
        insetBottom: CGFloat,
        epsilon: CGFloat = 1.5
    ) -> Bool {
        let minY = -insetTop
        let maxY = max(minY, contentHeight - boundsHeight + insetBottom)
        let visible = boundsHeight - insetTop - insetBottom
        let scrollable = contentHeight > visible + 0.5
        if !scrollable { return true }
        return offsetY >= maxY - epsilon
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

    public static func flingDirection(
        translation: CGSize,
        velocity: CGSize
    ) -> CGSize {
        let speed = hypot(velocity.width, velocity.height)
        let along = translation.width * velocity.width + translation.height * velocity.height
        let useVelocity = speed >= 80 && along > 0
        let x = useVelocity ? velocity.width : translation.width
        let y = useVelocity ? velocity.height : translation.height
        let mag = hypot(x, y)
        guard mag >= 1 else { return CGSize(width: 0, height: 1) }
        return CGSize(width: x / mag, height: y / mag)
    }

    public static func dismissTranslation(
        _ translation: CGSize,
        sheetSize: CGSize,
        velocity: CGSize = .zero
    ) -> CGSize {
        let dir = flingDirection(translation: translation, velocity: velocity)
        let travel = max(hypot(sheetSize.width, sheetSize.height), 1)
        return CGSize(width: dir.width * travel, height: dir.height * travel)
    }

    public static func clampedFlingSpeed(
        _ velocity: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> CGFloat {
        let speed = hypot(velocity.width, velocity.height)
        return min(configuration.maxFlingSpeed, max(configuration.minFlingSpeed, speed == 0 ? configuration.minFlingSpeed : speed))
    }

    public static func flingDuration(
        translation: CGSize,
        velocity: CGSize,
        sheetSize: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> TimeInterval {
        let target = dismissTranslation(translation, sheetSize: sheetSize, velocity: velocity)
        let remaining = hypot(target.width - translation.width, target.height - translation.height)
        let speed = clampedFlingSpeed(velocity, configuration: configuration)
        let duration = TimeInterval(remaining / speed)
        return min(configuration.maxFlingDuration, max(configuration.minFlingDuration, duration))
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
