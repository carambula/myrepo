//
//  BottomSheetPullToDismiss.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 3/1/26.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

private let pullToDismissEnabledKey = "bottom_sheet_pull_to_dismiss_enabled"
private let bottomSheetCloseButtonBlurModeKey = "bottom_sheet_close_button_blur_mode"
private let bottomSheetPresentationStyleKey = "bottom_sheet_presentation_style"

enum BottomSheetHandleStyle {
    static let width: CGFloat = 36
    static let height: CGFloat = 5
    static let topPadding: CGFloat = DesignSystem.Spacing.xs
    static let bottomPadding: CGFloat = DesignSystem.Spacing.xs
}

enum BottomSheetCloseButtonBlurMode: String, CaseIterable {
    case blurred = "Blurred (Glass)"
    case flat = "Flat (Reduced Blur)"
    
    static let storageKey = bottomSheetCloseButtonBlurModeKey
    static let `default` = BottomSheetCloseButtonBlurMode.blurred
}

enum BottomSheetPresentationStyle: String, CaseIterable {
    case `default` = "Default"
    case fullBleed = "Full Bleed"

    var description: String {
        switch self {
        case .default:
            return "Current behavior with top inset and drag handle."
        case .fullBleed:
            return "Slides up from the bottom and fills to the very top with no handle."
        }
    }

    static let storageKey = bottomSheetPresentationStyleKey
    static let defaultStyle = BottomSheetPresentationStyle.default
}

struct MovieDetailPresentationModifier<SheetContent: View>: ViewModifier {
    @Binding var selectedMovie: Movie?
    let style: BottomSheetPresentationStyle
    let onDismiss: () -> Void
    let content: (Movie) -> SheetContent

    func body(content base: Content) -> some View {
        switch style {
        case .default:
            base.sheet(item: $selectedMovie, onDismiss: onDismiss) { movie in
                self.content(movie)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        case .fullBleed:
            base.fullScreenCover(item: $selectedMovie, onDismiss: onDismiss) { movie in
                self.content(movie)
            }
        }
    }
}

private struct BottomSheetPullToDismissVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isBottomSheetPullToDismissVisible: Bool {
        get { self[BottomSheetPullToDismissVisibleKey.self] }
        set { self[BottomSheetPullToDismissVisibleKey.self] = newValue }
    }
}

// MARK: - Close Button View (WatchedIt-specific styling)

private struct CloseButtonView: View {
    let isActive: Bool
    @AppStorage(BottomSheetCloseButtonBlurMode.storageKey)
    private var blurModeRaw: String = BottomSheetCloseButtonBlurMode.default.rawValue
    @AppStorage(MainListToolbarStyle.storageKey)
    private var mainListToolbarStyleRaw: String = MainListToolbarStyle.system.rawValue
    
    private var blurMode: BottomSheetCloseButtonBlurMode {
        BottomSheetCloseButtonBlurMode(rawValue: blurModeRaw) ?? .default
    }

    private var closeButtonSize: CGFloat {
        mainListToolbarStyle == .customFloating ? 56 : 48
    }

    private var mainListToolbarStyle: MainListToolbarStyle {
        MainListToolbarStyle(rawValue: mainListToolbarStyleRaw) ?? .system
    }
    
    var body: some View {
        Image(systemName: DesignSystem.Icon.close)
            .font(DesignSystem.Typography.glassIcon)
            .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.textSecondary)
            .frame(width: closeButtonSize, height: closeButtonSize)
            .background {
                if blurMode == .flat {
                    Circle()
                        .fill(DesignSystem.Color.cardBackground.opacity(isActive ? 0.92 : 0.86))
                } else {
                    Circle()
                        .fill(GlassControl.floatingMaterial)
                }
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(
                        isActive
                            ? DesignSystem.Color.accent.opacity(0.35)
                            : GlassControl.Border.standard.color,
                        lineWidth: GlassControl.Border.standard.width
                    )
            }
            .shadow(
                color: isActive ? DesignSystem.Color.accent.opacity(0.2) : DesignSystem.Shadow.sm.color,
                radius: isActive ? 5 : 4,
                x: 0,
                y: 2
            )
            .scaleEffect(isActive ? 1.04 : 1.0)
            .opacity(isActive ? 1.0 : 0.5)
    }
}

// MARK: - View Extension

extension View {
    private var isBottomSheetPullToDismissEnabled: Bool {
        UserDefaults.standard.object(forKey: pullToDismissEnabledKey) as? Bool ?? true
    }

    @ViewBuilder
    func bottomSheetPullToDismiss() -> some View {
        #if os(iOS)
        if isBottomSheetPullToDismissEnabled {
            self.pullToDismissEngine(
                buttonAlignment: .bottom
            ) { isActive in
                CloseButtonView(isActive: isActive)
                    .frame(maxWidth: .infinity, alignment: closeButtonAlignment)
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
            .environment(\.isBottomSheetPullToDismissVisible, true)
        } else {
            self
        }
        #else
        self
        #endif
    }

    private var closeButtonAlignment: Alignment {
        if let data = UserDefaults.standard.data(forKey: MovieDetailLayoutParameters.storageKey) {
            let params = MovieDetailLayoutParameters.decode(from: data)
            return params.actionBarLayout == .leftAligned ? .leading : .center
        }
        return .center
    }
}
