// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WatchedItCore",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "WatchedItCore",
            targets: ["WatchedItCore"]
        )
    ],
    targets: [
        .target(
            name: "WatchedItCore",
            path: "WatchedIt",
            sources: [
                "AppDataBootstrapper.swift",
                "BootstrapDataService.swift",
                "CloudKitManager.swift",
                "ImageCache.swift",
                "ListPreferences.swift",
                "LocalDatabaseManager.swift",
                "Movie.swift",
                "MovieDataModel.swift",
                "MovieDataService.swift",
                "MovieModel.swift",
                "PodcastEpisodeIntakeService.swift",
                "PodcastAppPreferences.swift",
                "MinCloudSettings.swift",
                "RewatchablesCategories.swift",
                "Services/MinCloudClient.swift",
                "Services/MinCloudCatalogSync.swift",
                "StreamingPreferences.swift",
                "ThemeManager.swift",
                "TitleCleaner.swift",
                "OscarAwards.swift"
            ]
        )
    ]
)
