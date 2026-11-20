import MinAppKit
import SwiftUI

struct TrailingSwipeAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    var role: ButtonRole?
    let handler: () -> Void
}

enum TrailingSwipeMetrics {
    static let actionWidth: CGFloat = 72
    static let openThreshold: CGFloat = 0.35
    static let rubberBand: CGFloat = 4

    static func revealedWidth(actionCount: Int) -> CGFloat {
        CGFloat(max(actionCount, 0)) * actionWidth
    }

    static func clampedOffset(_ proposed: CGFloat, revealedWidth: CGFloat) -> CGFloat {
        if proposed > 0 {
            return proposed / rubberBand
        }
        if proposed < -revealedWidth {
            return -revealedWidth + (proposed + revealedWidth) / rubberBand
        }
        return proposed
    }

    static func restOffset(predictedOffset: CGFloat, revealedWidth: CGFloat) -> CGFloat {
        predictedOffset < -revealedWidth * openThreshold ? -revealedWidth : 0
    }

    static func isHorizontalDrag(translation: CGSize, minimumDistance: CGFloat = 12) -> Bool {
        let dx = abs(translation.width)
        let dy = abs(translation.height)
        return max(dx, dy) >= minimumDistance && dx > dy * 1.25
    }
}

struct TrailingSwipeActionsModifier: ViewModifier {
    @Binding var isRevealed: Bool
    @Binding var isDragActive: Bool
    let actions: [TrailingSwipeAction]

    @State private var offset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isHorizontalDrag = false

    private var revealedWidth: CGFloat {
        TrailingSwipeMetrics.revealedWidth(actionCount: actions.count)
    }

    private var visualOffset: CGFloat {
        TrailingSwipeMetrics.clampedOffset(offset, revealedWidth: revealedWidth)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                ForEach(actions) { action in
                    Button(role: action.role) {
                        close()
                        action.handler()
                    } label: {
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                            Text(action.title)
                                .font(DesignSystem.Typography.caption())
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(width: TrailingSwipeMetrics.actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(action.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(action.title)
                }
            }
            .allowsHitTesting(visualOffset < -20)

            content
                .background(DesignSystem.Colors.background)
                .offset(x: visualOffset)
                .overlay {
                    if isRevealed, !isHorizontalDrag {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(perform: close)
                    }
                }
        }
        .contentShape(Rectangle())
        .clipped()
        .simultaneousGesture(swipeGesture)
        .onChange(of: isRevealed) { _, revealed in
            guard !isHorizontalDrag else { return }
            withAnimation(MinAnimation.springQuick) {
                offset = revealed ? -revealedWidth : 0
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                if !isHorizontalDrag {
                    guard TrailingSwipeMetrics.isHorizontalDrag(translation: value.translation) else { return }
                    if !isRevealed, value.translation.width > 0 { return }
                    isHorizontalDrag = true
                    isDragActive = true
                    dragStartOffset = offset
                    isRevealed = true
                }

                offset = dragStartOffset + value.translation.width
            }
            .onEnded { value in
                let wasHorizontalDrag = isHorizontalDrag
                defer {
                    isHorizontalDrag = false
                    isDragActive = false
                }
                guard wasHorizontalDrag else { return }

                let predicted = visualOffset + value.predictedEndTranslation.width - value.translation.width
                let rest = TrailingSwipeMetrics.restOffset(
                    predictedOffset: predicted,
                    revealedWidth: revealedWidth
                )
                withAnimation(MinAnimation.springQuick) {
                    offset = rest
                    isRevealed = rest < 0
                }
            }
    }

    private func close() {
        withAnimation(MinAnimation.springQuick) {
            isRevealed = false
            offset = 0
        }
        isDragActive = false
        isHorizontalDrag = false
    }
}

extension View {
    func trailingSwipeActions(
        isRevealed: Binding<Bool>,
        isDragActive: Binding<Bool>,
        actions: [TrailingSwipeAction]
    ) -> some View {
        modifier(
            TrailingSwipeActionsModifier(
                isRevealed: isRevealed,
                isDragActive: isDragActive,
                actions: actions
            )
        )
    }
}
