//
//  ContentView.swift
//  YourTube
//
//  Created by Aaron Carámbula on 3/22/26.
//

import SwiftUI

struct ContentView: View {
    @Bindable var themeManager: ThemeManager
    @Bindable var authService: GoogleOAuthService
    @Bindable var syncStore: UserDataSyncStore
    @Binding var deepLinkVideoID: String?

    var body: some View {
        RootContentView(
            themeManager: themeManager,
            authService: authService,
            syncStore: syncStore,
            deepLinkVideoID: $deepLinkVideoID
        )
    }
}
