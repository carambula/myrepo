//
//  ToolbarBehaviorSettings.swift
//  WatchedIt
//
//  Created by Cursor on 3/7/26.
//

import SwiftUI
import Combine

// MARK: - Toolbar Scrolling Behavior

enum ToolbarScrollingBehavior: String, CaseIterable, Codable {
    case alwaysVisible = "Always Visible"
    case minimizeOnScroll = "Minimize on Scroll"
    case minimizeToCorners = "Minimize to Corners"
    case showHide = "Show/Hide"
    
    var description: String {
        switch self {
        case .alwaysVisible:
            return "Toolbar stays visible at all times. Current default behavior."
        case .minimizeOnScroll:
            return "Shrinks toolbar to a small pill in the center when scrolling down. Tap or scroll up to expand."
        case .minimizeToCorners:
            return "Moves filter bar to lower left and search to lower right when scrolling down."
        case .showHide:
            return "Hides toolbar completely when scrolling down. Slides back in when scrolling up."
        }
    }
    
    var icon: String {
        switch self {
        case .alwaysVisible:
            return "rectangle.bottomthird.inset.filled"
        case .minimizeOnScroll:
            return "arrow.up.and.down.circle"
        case .minimizeToCorners:
            return "arrow.down.left.and.arrow.up.right"
        case .showHide:
            return "eye.slash"
        }
    }
    
    static var storageKey: String {
        return "toolbarScrollingBehavior"
    }
}

// MARK: - Toolbar Scroll State

class ToolbarScrollState: ObservableObject {
    @Published var isMinimized: Bool = false
    @Published var lastScrollOffset: CGFloat = 0
    @Published var scrollDirection: ScrollDirection = .none
    private var directionalTravel: CGFloat = 0
    
    enum ScrollDirection {
        case up
        case down
        case none
    }
    
    func updateScroll(offset: CGFloat, threshold: CGFloat = 50) {
        let delta = offset - lastScrollOffset

        // Ignore tiny frame-to-frame jitter to prevent noisy transitions.
        guard abs(delta) > 0.5 else {
            lastScrollOffset = offset
            return
        }

        // In SwiftUI scroll coordinate space, moving content down the screen
        // (user scrolls up) increases minY, while scrolling down decreases minY.
        let newDirection: ScrollDirection = delta < 0 ? .down : .up

        if newDirection != scrollDirection {
            scrollDirection = newDirection
            directionalTravel = 0
        }

        directionalTravel += abs(delta)

        if directionalTravel >= threshold {
            if newDirection == .down {
                isMinimized = true
            } else {
                isMinimized = false
            }
            directionalTravel = 0
        }

        lastScrollOffset = offset
    }
    
    func reset() {
        isMinimized = false
        lastScrollOffset = 0
        scrollDirection = .none
        directionalTravel = 0
    }
    
    func expand() {
        isMinimized = false
    }
    
    func minimize() {
        isMinimized = true
    }
}

// MARK: - Scroll Offset Reader

import MinAppKit

struct ScrollOffsetReader<Content: View>: View {
    let content: Content
    let onOffsetChange: (CGFloat) -> Void

    init(@ViewBuilder content: () -> Content, onOffsetChange: @escaping (CGFloat) -> Void) {
        self.content = content()
        self.onOffsetChange = onOffsetChange
    }

    var body: some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scrollView")).minY
                )
            }
            .frame(height: 0)

            content
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            onOffsetChange(value)
        }
    }
}
