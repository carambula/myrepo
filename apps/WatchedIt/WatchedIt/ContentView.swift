//
//  ContentView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI

// Compatibility root for previews/legacy callers.
struct ContentView: View {
    var body: some View {
        CollectionsHomeView(deepLinkURL: .constant(nil))
    }
}

#Preview {
    ContentView()
}
