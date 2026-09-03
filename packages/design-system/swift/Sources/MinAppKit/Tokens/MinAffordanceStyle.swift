import Observation
import SwiftUI

/// Type-erased `InsettableShape` so affordance clips and `strokeBorder` can switch
/// between round (circle/capsule) and square (rounded rectangle) geometry.
public struct AnyInsettableShape: InsettableShape {
    private let _path: (CGRect) -> Path
    private let _inset: (CGFloat) -> AnyInsettableShape

    public init<S: InsettableShape>(_ shape: S) {
        _path = { rect in shape.path(in: rect) }
        _inset = { amount in AnyInsettableShape(shape.inset(by: amount)) }
    }

    public func path(in rect: CGRect) -> Path {
        _path(rect)
    }

    public func inset(by amount: CGFloat) -> AnyInsettableShape {
        _inset(amount)
    }
}

/// Shared button and control geometry for every min app.
///
/// Appearance sheets bind `borderEnabled` and `shape`. Round uses circle/capsule;
/// square uses a continuous rounded rectangle. Shape accessors are `nonisolated`
/// so `Shape.path(in:)` and other helpers (for example `ViewSurface`) can read
/// them off the main actor. Use the `insettable*` variants with `strokeBorder`
/// and frosted surfaces.
@Observable
public final class MinAffordanceStyle {
    nonisolated(unsafe) public static let shared = MinAffordanceStyle()

    public enum Shape: String, CaseIterable, Identifiable, Sendable {
        case round
        case square

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .round: return "Round"
            case .square: return "Square"
            }
        }
    }

    public var borderEnabled: Bool {
        didSet { UserDefaults.standard.set(borderEnabled, forKey: Self.borderKey) }
    }

    public var shape: Shape {
        didSet { UserDefaults.standard.set(shape.rawValue, forKey: Self.shapeKey) }
    }

    public nonisolated var isSquare: Bool { Self.persistedShape == .square }

    /// Circle when round; rounded square when square. Use for icon buttons.
    public nonisolated var circleShape: AnyShape {
        Self.circleShape(for: Self.persistedShape)
    }

    /// Capsule when round; rounded rectangle when square. Use for bars and fields.
    public nonisolated var capsuleShape: AnyShape {
        Self.capsuleShape(for: Self.persistedShape)
    }

    public nonisolated var insettableCircleShape: AnyInsettableShape {
        Self.insettableCircleShape(for: Self.persistedShape)
    }

    public nonisolated var insettableCapsuleShape: AnyInsettableShape {
        Self.insettableCapsuleShape(for: Self.persistedShape)
    }

    public static var borderColor: Color {
        Color.primary.opacity(0.18)
    }

    public static let borderLineWidth: CGFloat = 1

    public nonisolated static func circleShape(for shape: Shape) -> AnyShape {
        switch shape {
        case .round: AnyShape(Circle())
        case .square: AnyShape(squareRect)
        }
    }

    public nonisolated static func capsuleShape(for shape: Shape) -> AnyShape {
        switch shape {
        case .round: AnyShape(Capsule())
        case .square: AnyShape(squareRect)
        }
    }

    public nonisolated static func insettableCircleShape(for shape: Shape) -> AnyInsettableShape {
        switch shape {
        case .round: AnyInsettableShape(Circle())
        case .square: AnyInsettableShape(squareRect)
        }
    }

    public nonisolated static func insettableCapsuleShape(for shape: Shape) -> AnyInsettableShape {
        switch shape {
        case .round: AnyInsettableShape(Capsule())
        case .square: AnyInsettableShape(squareRect)
        }
    }

    private static let borderKey = "min.affordance.borderEnabled"
    private static let shapeKey = "min.affordance.shape"

    /// Stored independently of actor isolation so `Shape.path(in:)` can resolve geometry.
    private nonisolated static var persistedShape: Shape {
        Shape(rawValue: UserDefaults.standard.string(forKey: shapeKey) ?? "") ?? .round
    }

    private nonisolated static var squareRect: RoundedRectangle {
        RoundedRectangle(cornerRadius: MinCornerRadius.md, style: .continuous)
    }

    private init() {
        if UserDefaults.standard.object(forKey: Self.borderKey) is Bool {
            borderEnabled = UserDefaults.standard.bool(forKey: Self.borderKey)
        } else {
            borderEnabled = false
        }
        if let raw = UserDefaults.standard.string(forKey: Self.shapeKey),
           let stored = Shape(rawValue: raw) {
            shape = stored
        } else {
            shape = .round
        }
    }
}
