import SwiftUI

extension View {
    /// Card-style elevation with surface background and rounded corners.
    public func minCard(
        cornerRadius: CGFloat = MinCornerRadius.lg,
        shadow: MinShadow.Spec = MinShadow.md
    ) -> some View {
        self
            .background(.background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Frosted glass surface — circle or rounded rect with thick material.
    public func frostedSurface<S: Shape>(
        _ shape: S,
        material: Material = .thinMaterial,
        borderColor: Color = .secondary.opacity(0.3),
        borderWidth: CGFloat = 0.5
    ) -> some View {
        self
            .background(material)
            .clipShape(shape)
            .overlay { if MinAffordanceStyle.shared.borderEnabled { shape.stroke(borderColor, lineWidth: borderWidth) } }
    }

    /// Frosted glass surface that respects `MinAffordanceStyle` shape settings.
    public func affordanceFrostedSurface(
        roundShape: AffordanceRoundVariant,
        material: Material = .thinMaterial,
        borderColor: Color = .secondary.opacity(0.3),
        borderWidth: CGFloat = 0.5
    ) -> some View {
        let shape = roundShape.resolvedShape
        return self
            .background(material)
            .clipShape(shape)
            .overlay { if MinAffordanceStyle.shared.borderEnabled { shape.stroke(borderColor, lineWidth: borderWidth) } }
    }
}

public enum AffordanceRoundVariant {
    case capsule
    case circle

    public var resolvedShape: AnyShape {
        switch self {
        case .capsule: return MinAffordanceStyle.shared.capsuleShape
        case .circle:  return MinAffordanceStyle.shared.circleShape
        }
    }
}
