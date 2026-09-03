//
//  BottomSheetPullToDismiss.swift
//  Cyclismo
//
//  Uses shared MinAppKit pull-to-dismiss engine with Cyclismo glass styling.
//

import SwiftUI

#if os(iOS)
import UIKit

// MARK: - Close Button View (Cyclismo gradient glass styling)

private struct CloseButtonView: View {
    let isActive: Bool

    var body: some View {
        let cs = MinAffordanceStyle.shared.circleShape
        ZStack {
            cs
                .fill(.thinMaterial)
                .background {
                    cs
                        .fill(.thinMaterial)
                        .blur(radius: 8)
                }
                .overlay {
                    if MinAffordanceStyle.shared.borderEnabled {
                        ZStack {
                            cs
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(isActive ? 0.4 : 0.2),
                                            .white.opacity(isActive ? 0.15 : 0.08),
                                            .clear,
                                            .white.opacity(isActive ? 0.2 : 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                            cs
                                .stroke(
                                    isActive ? DesignSystem.Color.accent.opacity(0.6) : DesignSystem.Color.textSecondary.opacity(0.4),
                                    lineWidth: 1
                                )
                        }
                    }
                }
                .overlay {
                    cs
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isActive ? 0.1 : 0.05),
                                    .white.opacity(isActive ? 0.04 : 0.02),
                                    .clear,
                                    .white.opacity(isActive ? 0.02 : 0.01)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: isActive ? DesignSystem.Color.accent.opacity(0.4) : Color.black.opacity(0.15),
                    radius: isActive ? 10 : 5,
                    x: 0,
                    y: 2
                )

            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(isActive ? DesignSystem.Color.accent : DesignSystem.Color.textSecondary)
        }
        .frame(width: 50, height: 50)
        .scaleEffect(isActive ? 1.04 : 1.0)
        .opacity(isActive ? 1.0 : 0.5)
    }
}

extension View {
    func bottomSheetPullToDismiss() -> some View {
        self.pullToDismissEngine(
            configuration: PullToDismissConfiguration(windowScan: true),
            buttonAlignment: .bottomLeading
        ) { isActive in
            CloseButtonView(isActive: isActive)
                .padding(.leading, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}

#else

extension View {
    func bottomSheetPullToDismiss() -> some View {
        self
    }
}

#endif
