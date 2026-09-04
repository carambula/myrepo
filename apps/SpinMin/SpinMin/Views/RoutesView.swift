//
//  RoutesView.swift
//  SpinMin
//
//  Route library: import GPX files, browse, and manage saved routes
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RoutesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Route.name) private var routes: [Route]
    
    @State private var showingImporter = false
    @State private var importError: String?
    
    private static let gpxType = UTType(filenameExtension: "gpx") ?? .xml
    
    var body: some View {
        List {
            if routes.isEmpty {
                ContentUnavailableView(
                    "No Routes",
                    systemImage: "map",
                    description: Text("Import a GPX file from Strava, RideWithGPS, or Komoot to build your route library.")
                )
            } else {
                ForEach(routes) { route in
                    RouteRow(route: route)
                }
                .onDelete(perform: deleteRoutes)
            }
        }
        .navigationTitle("Routes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import GPX", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [Self.gpxType, .xml],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("Import Failed", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }
    
    // MARK: - Import
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            for url in urls {
                do {
                    try importGPX(from: url)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
    }
    
    private func importGPX(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        let data = try Data(contentsOf: url)
        let gpx = try GPXParser.parse(data: data)
        
        let route = Route(
            name: gpx.name ?? url.deletingPathExtension().lastPathComponent,
            distance: gpx.distanceKm,
            routeType: gpx.isLoop ? .loop : .pointToPoint,
            surfaceType: .paved,
            elevation: gpx.elevationGainM > 0 ? gpx.elevationGainM : nil,
            notes: "Imported from GPX"
        )
        if let start = gpx.startCoordinate {
            route.startLatitude = start.latitude
            route.startLongitude = start.longitude
        }
        
        modelContext.insert(route)
    }
    
    private func deleteRoutes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routes[index])
        }
    }
}

// MARK: - Route Row

private struct RouteRow: View {
    @Bindable var route: Route
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(route.name)
                    .bodyMedium()
                Spacer()
                if route.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .captionMedium()
                }
            }
            
            Text(routeSubtitle)
                .captionMedium()
                .foregroundStyle(.secondary)
            
            Picker("Surface", selection: surfaceBinding) {
                ForEach(SurfaceType.allCases, id: \.self) { surface in
                    Text(surface.displayName).tag(surface)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .swipeActions(edge: .leading) {
            Button {
                route.isFavorite.toggle()
            } label: {
                Label("Favorite", systemImage: route.isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
    }
    
    private var routeSubtitle: String {
        var parts = [String(format: "%.1f km", route.distance)]
        if let elevation = route.elevation {
            parts.append("\(Int(elevation)) m climbing")
        }
        if route.timesRidden > 0 {
            parts.append("ridden \(route.timesRidden)x")
        }
        return parts.joined(separator: "   ")
    }
    
    private var surfaceBinding: Binding<SurfaceType> {
        Binding(
            get: { SurfaceType(rawValue: route.surfaceTypeRawValue) ?? .paved },
            set: { route.surfaceTypeRawValue = $0.rawValue }
        )
    }
}
