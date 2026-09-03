import SwiftUI

private struct RaceImageTwoToneModifier: ViewModifier {
    // Proper duotone mapping:
    // low luminance -> shadowTone, high luminance -> highlightTone.
    private var shadowTone: Color {
        DesignSystem.Color.duotoneShadow
    }

    private var highlightTone: Color {
        DesignSystem.Color.duotoneHighlight
    }

    func body(content: Content) -> some View {
        ZStack {
            shadowTone
            highlightTone
                .mask {
                    content
                        .saturation(0)
                        .luminanceToAlpha()
                }
        }
        // Preserve original alpha edges if artwork contains transparency.
        .mask(content)
        .compositingGroup()
    }
}

extension View {
    func raceImageTwoTone() -> some View {
        modifier(RaceImageTwoToneModifier())
    }
}
