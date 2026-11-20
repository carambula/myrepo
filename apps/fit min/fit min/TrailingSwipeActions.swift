import MinAppKit
import SwiftUI

struct TrailingSwipeAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let handler: () -> Void
}

enum TrailingSwipeMetrics {
    static let actionWidth: CGFloat = DesignSystem.Controls.iconButtonSize
    static let actionSpacing: CGFloat = DesignSystem.Spacing.sm
    static let trailingInset: CGFloat = DesignSystem.Spacing.lg
    static let openThreshold: CGFloat = 0.35
    static let rubberBand: CGFloat = 4

    static func revealedWidth(actionCount: Int) -> CGFloat {
        guard actionCount > 0 else { return 0 }
        return CGFloat(actionCount) * actionWidth
            + CGFloat(actionCount - 1) * actionSpacing
            + trailingInset
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
    @GestureState private var isGestureDragging = false

    private var revealedWidth: CGFloat {
        TrailingSwipeMetrics.revealedWidth(actionCount: actions.count)
    }

    private var visualOffset: CGFloat {
        TrailingSwipeMetrics.clampedOffset(offset, revealedWidth: revealedWidth)
    }

    func body(content: Content) -> some View {
        content
            .offset(x: visualOffset)
            .overlay {
                if isRevealed, !isHorizontalDrag {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: close)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(swipeGesture)
            .overlay(alignment: .trailing) {
                actionButtons
                    .offset(x: visualOffset + revealedWidth)
                    .zIndex(1)
            }
            .clipped()
            .onChange(of: isGestureDragging) { _, dragging in
                isDragActive = dragging
                if !dragging {
                    isHorizontalDrag = false
                }
            }
            .onChange(of: isRevealed) { _, revealed in
                guard !isHorizontalDrag else { return }
                withAnimation(MinAnimation.springQuick) {
                    offset = revealed ? -revealedWidth : 0
                }
                if !revealed {
                    isDragActive = false
                }
            }
            .onDisappear {
                isDragActive = false
                isHorizontalDrag = false
            }
    }

    private var actionButtons: some View {
        HStack(spacing: TrailingSwipeMetrics.actionSpacing) {
            ForEach(actions) { action in
                Button {
                    perform(action)
                } label: {
                    Image(systemName: action.systemImage)
                }
                .buttonStyle(CircularGlassIconButtonStyle())
                .accessibilityLabel(action.title)
            }
        }
        .padding(.trailing, TrailingSwipeMetrics.trailingInset)
        .frame(maxHeight: .infinity)
        .allowsHitTesting(visualOffset < -20)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($isGestureDragging) { value, state, _ in
                let isOpeningSwipe = value.translation.width < 0
                if state || (TrailingSwipeMetrics.isHorizontalDrag(translation: value.translation) && (isRevealed || isOpeningSwipe)) {
                    state = true
                }
            }
            .onChanged { value in
                if !isHorizontalDrag {
                    guard TrailingSwipeMetrics.isHorizontalDrag(translation: value.translation) else { return }
                    if !isRevealed, value.translation.width > 0 { return }
                    isHorizontalDrag = true
                    dragStartOffset = offset
                    isRevealed = true
                }

                offset = dragStartOffset + value.translation.width
            }
            .onEnded { value in
                let wasHorizontalDrag = isHorizontalDrag
                isHorizontalDrag = false
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

    private func perform(_ action: TrailingSwipeAction) {
        isDragActive = false
        isHorizontalDrag = false
        withAnimation(MinAnimation.springQuick) {
            isRevealed = false
            offset = 0
        }
        action.handler()
    }

    private func close() {
        isDragActive = false
        isHorizontalDrag = false
        withAnimation(MinAnimation.springQuick) {
            isRevealed = false
            offset = 0
        }
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
