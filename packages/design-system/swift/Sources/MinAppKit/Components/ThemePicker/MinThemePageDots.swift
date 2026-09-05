import SwiftUI

public struct MinThemePageDots: View {
    public let count: Int
    public let currentIndex: Int
    public let accentColor: Color

    public init(count: Int, currentIndex: Int, accentColor: Color) {
        self.count = count
        self.currentIndex = currentIndex
        self.accentColor = accentColor
    }

    public var body: some View {
        HStack(spacing: MinSpacing.sm) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? accentColor : Color.primary.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.18), value: currentIndex)
            }
        }
        .padding(.top, MinSpacing.xs)
    }
}
