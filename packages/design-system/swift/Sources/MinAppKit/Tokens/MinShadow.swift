import SwiftUI

public enum MinShadow {
    public struct Spec {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat

        public init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }

    public static let sm = Spec(color: .black.opacity(0.08), radius: 2, y: 1)
    public static let md = Spec(color: .black.opacity(0.12), radius: 4, y: 2)
    public static let lg = Spec(color: .black.opacity(0.16), radius: 8, y: 4)
    public static let xl = Spec(color: .black.opacity(0.20), radius: 16, y: 8)
}

extension View {
    public func minShadow(_ spec: MinShadow.Spec) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
