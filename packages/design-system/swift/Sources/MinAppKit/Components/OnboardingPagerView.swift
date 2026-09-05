import SwiftUI

/// Shared paged onboarding shell used by min apps.
///
/// Provides a `TabView` with page dots, current page state, and a
/// completion binding. Each app supplies its own step content.
///
/// ```swift
/// OnboardingPagerView(pageCount: 3, hasCompleted: $done) { page, advance in
///     switch page {
///     case 0: WelcomePage(onContinue: advance)
///     case 1: FeaturesPage(onContinue: advance)
///     default: ThemePage(onFinish: { done = true })
///     }
/// }
/// ```
public struct OnboardingPagerView<Content: View>: View {
    public let pageCount: Int
    @Binding public var hasCompleted: Bool
    @ViewBuilder public let content: (_ page: Int, _ advance: @escaping () -> Void) -> Content

    @State private var currentPage = 0

    public init(
        pageCount: Int,
        hasCompleted: Binding<Bool>,
        @ViewBuilder content: @escaping (_ page: Int, _ advance: @escaping () -> Void) -> Content
    ) {
        self.pageCount = pageCount
        self._hasCompleted = hasCompleted
        self.content = content
    }

    public var body: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pageCount, id: \.self) { page in
                content(page) {
                    if page < pageCount - 1 {
                        withAnimation { currentPage = page + 1 }
                    } else {
                        hasCompleted = true
                    }
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
