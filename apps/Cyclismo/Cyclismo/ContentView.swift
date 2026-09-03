//
//  ContentView.swift
//  Cyclismo
//
//  Created by Aaron Carámbula on 2/8/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Binding var deepLinkURL: URL?

    var body: some View {
        if hasCompletedOnboarding {
            NavigationStack {
                RaceListView(deepLinkURL: $deepLinkURL)
            }
            .themeBackground()
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView(deepLinkURL: .constant(nil))
}
