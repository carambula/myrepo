//
//  ListSelectorView.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI
import SwiftData

struct ListSelectorView: View {
    let movie: Movie
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DataSource.name) private var allDataSources: [DataSource]
    @State private var showCreateList = false
    @State private var newListName = ""
    
    // Filter to only local lists
    var localLists: [DataSource] {
        allDataSources.filter { $0.type == "local" }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if localLists.isEmpty {
                    EmptyStateView(
                        title: "No Lists",
                        description: "Create your first list to organize movies."
                    )
                } else {
                    List {
                        ForEach(localLists) { list in
                            Button(action: {
                                addMovieToList(list)
                            }) {
                                HStack {
                                    Text(list.name)
                                    Spacer()
                                    if isMovieInList(list) {
                                        Image(systemName: "checkmark")
                                            .foregroundAccent()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .designSystemGroupedListRow()
                        }
                    }
                    .designSystemGroupedListStyle()
                }
            }
            .background(DesignSystem.Color.background)
            .tint(DesignSystem.Color.accent)
            .navigationTitle("Add to List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showCreateList = true
                    } label: {
                        Image(systemName: DesignSystem.Icon.add)
                    }
                    .accessibilityLabel("Create list")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: DesignSystem.Icon.checkmark)
                    }
                    .accessibilityLabel("Done")
                }
            }
            .alert("New List", isPresented: $showCreateList) {
                TextField("List Name", text: $newListName)
                Button("Cancel", role: .cancel) {
                    newListName = ""
                }
                Button("Create") {
                    createList()
                }
            } message: {
                Text("Enter a name for your new list")
            }
        }
    }
    
    private func isMovieInList(_ list: DataSource) -> Bool {
        guard let movieData = getMovieData() else { return false }
        return list.movieDataSources?.contains { $0.movie?.id == movieData.id } ?? false
    }
    
    private func getMovieData() -> MovieData? {
        let descriptor = FetchDescriptor<MovieData>(
            predicate: #Predicate<MovieData> { $0.id == movie.id }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func addMovieToList(_ list: DataSource) {
        guard let movieData = getMovieData() else { return }
        
        // Check if already in list
        if let existingEntry = list.movieDataSources?.first(where: { $0.movie?.id == movieData.id }) {
            // Remove from list
            modelContext.delete(existingEntry)
        } else {
            // Add to list using MovieDataSource
            let entry = MovieDataSource(movie: movieData, dataSource: list)
            modelContext.insert(entry)
        }
        
        list.lastUpdated = Date()
        
        do {
            try modelContext.save()
            // Notify that the list needs to refresh
            NotificationCenter.default.post(name: NSNotification.Name("MovieListNeedsRefresh"), object: nil)
        } catch {
            print("Error saving list entry: \(error)")
        }
    }
    
    private func createList() {
        guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let list = DataSource(
            identifier: UUID().uuidString,
            name: newListName.trimmingCharacters(in: .whitespaces),
            type: "local",
            url: nil,
            isEnabled: true
        )
        modelContext.insert(list)
        
        do {
            try modelContext.save()
            
            // Automatically add movie to the new list
            if let movieData = getMovieData() {
                let entry = MovieDataSource(movie: movieData, dataSource: list)
                modelContext.insert(entry)
                try modelContext.save()
            }
            
            newListName = ""
            showCreateList = false
            
            // Notify that the list needs to refresh
            NotificationCenter.default.post(name: NSNotification.Name("MovieListNeedsRefresh"), object: nil)
        } catch {
            print("Error creating list: \(error)")
        }
    }
}

