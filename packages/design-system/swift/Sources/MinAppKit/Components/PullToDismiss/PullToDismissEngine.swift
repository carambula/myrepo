#if os(iOS)
import SwiftUI
import UIKit

/// Configuration for pull-to-dismiss thresholds and haptics.
public struct PullToDismissConfiguration {
    public var pullThreshold: CGFloat
    public var activationThreshold: CGFloat
    public var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    public var windowScan: Bool

    public init(
        pullThreshold: CGFloat = 50,
        activationThreshold: CGFloat = 90,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        windowScan: Bool = false
    ) {
        self.pullThreshold = pullThreshold
        self.activationThreshold = activationThreshold
        self.hapticStyle = hapticStyle
        self.windowScan = windowScan
    }

    public static let `default` = PullToDismissConfiguration()
}

/// Shared pull-to-dismiss engine modifier. Handles scroll introspection,
/// overscroll tracking, haptics, and dismiss-on-release.
///
/// Each app provides its own close button view via the `closeButton` builder.
/// The builder receives `isActive` (true when past the activation threshold)
/// so the button can change appearance.
public struct PullToDismissEngineModifier<CloseButton: View>: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var scrollObserver = PullToDismissScrollObserver()
    @State private var isAtBottom: Bool = false
    @State private var overscrollDistance: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showButton: Bool = false
    @State private var isButtonActive: Bool = false
    @State private var isDismissing: Bool = false
    @State private var hapticGenerator: UIImpactFeedbackGenerator?

    public let configuration: PullToDismissConfiguration
    public let buttonAlignment: Alignment
    @ViewBuilder public let closeButton: (_ isActive: Bool) -> CloseButton

    public init(
        configuration: PullToDismissConfiguration = .default,
        buttonAlignment: Alignment = .bottomLeading,
        @ViewBuilder closeButton: @escaping (_ isActive: Bool) -> CloseButton
    ) {
        self.configuration = configuration
        self.buttonAlignment = buttonAlignment
        self.closeButton = closeButton
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: buttonAlignment) {
            content
                .background(
                    PullToDismissIntrospector(
                        observer: scrollObserver,
                        windowScan: configuration.windowScan
                    )
                    .frame(width: 0, height: 0)
                )
                .onChange(of: overscrollDistance) { _, newValue in
                    handleOverscroll(newValue)
                }
                .onChange(of: isDragging) { oldValue, newValue in
                    if !newValue && oldValue {
                        handleDragEnded(releasedWhileActive: isButtonActive)
                    }
                }
                .onAppear {
                    prepareHapticGenerator()
                    scrollObserver.onStateChange = { newState in
                        isAtBottom = newState.isAtBottom
                        overscrollDistance = newState.overscrollDistance
                        isDragging = newState.isDragging
                    }
                }
                .onDisappear {
                    scrollObserver.onStateChange = nil
                }

            closeButton(isButtonActive)
                .opacity(showButton ? 1 : 0.001)
                .offset(y: showButton ? 0 : 20)
                .allowsHitTesting(showButton)
        }
    }

    private func handleOverscroll(_ distance: CGFloat) {
        guard isDragging else { return }

        if distance > configuration.pullThreshold && isAtBottom {
            if !showButton {
                prepareHapticGenerator()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showButton = true
                }
            }
            if distance > configuration.activationThreshold {
                if !isButtonActive {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isButtonActive = true
                    }
                    hapticGenerator?.impactOccurred()
                    prepareHapticGenerator()
                }
            } else if isButtonActive {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isButtonActive = false
                }
            }
        } else if showButton {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                showButton = false
                isButtonActive = false
            }
        }
    }

    private func handleDragEnded(releasedWhileActive: Bool) {
        guard !isDismissing else { return }
        if releasedWhileActive {
            isDismissing = true
            dismiss()
            return
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            showButton = false
            isButtonActive = false
        }
    }

    private func prepareHapticGenerator() {
        let generator = hapticGenerator ?? UIImpactFeedbackGenerator(style: configuration.hapticStyle)
        generator.prepare()
        hapticGenerator = generator
    }
}

extension View {
    /// Attach the shared pull-to-dismiss engine to a bottom sheet.
    ///
    /// Provide your own close button styling via the `closeButton` builder:
    /// ```swift
    /// .pullToDismissEngine { isActive in
    ///     MyCloseButton(isActive: isActive)
    /// }
    /// ```
    public func pullToDismissEngine<CloseButton: View>(
        configuration: PullToDismissConfiguration = .default,
        buttonAlignment: Alignment = .bottomLeading,
        @ViewBuilder closeButton: @escaping (_ isActive: Bool) -> CloseButton
    ) -> some View {
        modifier(PullToDismissEngineModifier(
            configuration: configuration,
            buttonAlignment: buttonAlignment,
            closeButton: closeButton
        ))
    }
}
#endif
