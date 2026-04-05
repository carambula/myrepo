#!/usr/bin/env swift

import Foundation

/// Script to add RT Essential Movies for Kids (50) and RT Best Christmas Movies (100) to bootstrap_data.json
/// and enrich them with TMDB data

// MARK: - Data Structures

struct BootstrapDataSource: Codable {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isRankedList: Bool
    var movieCount: Int
}

struct BootstrapMovie: Codable {
    var title: String
    var sourceIdentifier: String
    var rank: Int?
    var sourceTitle: String?
    
    var tmdbId: Int?
    var year: Int?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var mpaaRating: String?
    var genres: [String]?
    var streamingServices: [BootstrapStreamingService]?
    var credits: BootstrapCredits?
    var trailer: BootstrapTrailer?
    var podcastEpisodeDescription: String?
}

struct BootstrapStreamingService: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int
}

struct BootstrapCredits: Codable {
    let director: String?
    let cast: [BootstrapCastMember]?
}

struct BootstrapCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
}

struct BootstrapTrailer: Codable {
    let id: String
    let name: String
    let youtubeKey: String
    let isOfficial: Bool
}

struct BootstrapData: Codable {
    var version: String?
    var generatedDate: String?
    var dataSources: [BootstrapDataSource]
    var movies: [BootstrapMovie]
}

// MARK: - Movie Lists

struct MovieListConfig {
    let identifier: String
    let name: String
    let url: String
    let titles: [String]
}

let rtKidsTitles = [
    "Beauty and the Beast (1991)", "Chicken Run (2000)", "Frozen (2013)", "Kiki's Delivery Service (1989)",
    "A Little Princess (1995)", "The Muppet Movie (1979)", "My Neighbor Totoro (1988)", "The Red Balloon (1956)",
    "Snow White and the Seven Dwarfs (1937)", "Toy Story (1995)", "WALL-E (2008)", "The Wizard of Oz (1939)",
    "Babe (1995)", "Back to the Future (1985)", "Coco (2017)", "E.T. the Extra-Terrestrial (1982)",
    "Elf (2003)", "Fantastic Mr. Fox (2009)", "The Goonies (1985)", "Harry Potter and the Sorcerer's Stone (2001)",
    "Home Alone (1990)", "How to Train Your Dragon (2010)", "Inside Out (2015)", "The Karate Kid (1984)",
    "The Iron Giant (1999)", "The LEGO Movie (2014)", "Little Manhattan (2005)", "Matilda (1996)",
    "The Neverending Story (1984)", "Paddington 2 (2017)", "The Princess Bride (1987)", "The Sandlot (1993)",
    "Spirited Away (2001)", "Spy Kids (2001)", "Star Wars: Episode IV – A New Hope (1977)", "Willy Wonka and the Chocolate Factory (1971)",
    "The 400 Blows (1959)", "Akeelah and the Bee (2006)", "Au Revoir, les enfants (1987)", "Hugo (2011)",
    "Napoleon Dynamite (2004)", "Pee-wee's Big Adventure (1985)", "Queen of Katwe (2016)", "Raiders of the Lost Ark (1981)",
    "Romeo and Juliet (1968)", "Rudy (1993)", "Spider-Man: Into the Spider-Verse (2018)", "Time Bandits (1981)",
    "West Side Story (1961)", "The Witches (1990)"
]

let rtChristmasTitles = [
    "The Shop Around the Corner (1940)", "Meet Me in St. Louis (1944)", "The Holdovers (2023)", "Tangerine (2015)",
    "Miracle on 34th Street (1947)", "Little Women (2019)", "Tim Burton's The Nightmare Before Christmas (1993)", "Klaus (2019)",
    "Carol (2015)", "It's a Wonderful Life (1946)", "Die Hard (1988)", "The Guardians of the Galaxy Holiday Special (2022)",
    "Arthur Christmas (2011)", "The Apartment (1960)", "Little Women (1994)", "Tokyo Godfathers (2003)",
    "Jingle Jangle: A Christmas Journey (2020)", "Edward Scissorhands (1990)", "Rare Exports: A Christmas Tale (2010)", "A Christmas Story (1983)",
    "Better Watch Out (2016)", "Spoiler Alert (2022)", "Gremlins (1984)", "Trading Places (1983)",
    "Kiss Kiss, Bang Bang (2005)", "A Christmas Tale (2008)", "Elf (2003)", "Happiest Season (2020)",
    "Batman Returns (1992)", "While You Were Sleeping (1995)", "Christmas Eve in Miller's Point (2024)", "The Man Who Invented Christmas (2017)",
    "A Christmas Story Christmas (2022)", "Bad Santa (2003)", "The Muppet Christmas Carol (1992)", "Anna and the Apocalypse (2017)",
    "White Christmas (1954)", "Happy Christmas (2014)", "Merry Christmas (2005)", "LEGO Star Wars Holiday Special (2020)",
    "The Santa Clause (1994)", "The Ref (1994)", "How the Grinch Stole Christmas (1967)", "Holiday Inn (1942)",
    "Rudolph the Red-Nosed Reindeer (1964)", "The Best Christmas Pageant Ever (2024)", "A Very Jonas Christmas Movie (2025)", "White Reindeer (2013)",
    "The Year Without a Santa Claus (1974)", "Christmas in Connecticut (1945)", "Dear Santa (2020)", "A Christmas Carol (1951)",
    "A Charlie Brown Christmas (1965)", "The Bishop's Wife (1947)", "Let It Snow (2019)", "8-Bit Christmas (2021)",
    "A Boy Called Christmas (2021)", "It's a Very Merry Muppet Christmas Movie (2002)", "Get Santa (2014)", "A Castle for Christmas (2021)",
    "The Little Drummer Boy (1968)", "Violent Night (2022)", "Frosty the Snowman (1969)", "National Lampoon's Christmas Vacation (1989)",
    "Something from Tiffany's (2022)", "The Best Man Holiday (2013)", "Scrooged (1988)", "Black Christmas (1974)",
    "The Knight Before Christmas (2019)", "Spirited (2022)", "Single All the Way (2021)", "A Very Harold & Kumar Christmas (2011)",
    "The Night Before (2015)", "Godmothered (2020)", "Prancer (1989)", "Krampus (2015)",
    "The Christmas Chronicles (2018)", "Home Alone (1990)", "The Christmas Chronicles 2 (2020)", "Love Actually (2003)",
    "Falling for Christmas (2022)", "The Preacher's Wife (1996)", "Dr. Seuss' The Grinch (2018)", "Silent Night (2023)",
    "Miracle on 34th Street (1994)", "Last Holiday (2006)", "Noelle (2019)", "The Santa Clause 2 (2002)",
    "The Princess Switch: Switched Again (2020)", "The Polar Express (2004)", "The Apology (2022)", "The Family Man (2000)",
    "Nothing Like the Holidays (2008)", "Love Hard (2021)", "The Family Stone (2005)", "The Holiday (2006)",
    "How the Grinch Stole Christmas (2000)", "One Magic Christmas (1985)", "Last Christmas (2019)", "Candy Cane Lane (2023)"
]

// MARK: - TMDB Service

class TMDBService {
    private let apiKey = "4f6ab1dde752aedd41093bab21f383c7"
    private let baseURL = "https://api.themoviedb.org/3"
    
    struct TMDBSearchResponse: Codable {
        let results: [TMDBMovie]
    }
    
    struct TMDBMovie: Codable {
        let id: Int
        let title: String
        let release_date: String?
        let poster_path: String?
        let backdrop_path: String?
        let overview: String?
    }
    
    struct TMDBMovieDetails: Codable {
        let id: Int
        let title: String
        let release_date: String?
        let poster_path: String?
        let backdrop_path: String?
        let overview: String?
        let genres: [TMDBGenre]?
        let release_dates: TMDBReleaseDates?
        
        var mpaaRating: String? {
            release_dates?.results?.first { $0.iso_3166_1 == "US" }?
                .release_dates.first { $0.certification != nil && !$0.certification!.isEmpty }?
                .certification
        }
    }
    
    struct TMDBGenre: Codable {
        let id: Int
        let name: String
    }
    
    struct TMDBReleaseDates: Codable {
        let results: [TMDBReleaseDateResult]?
    }
    
    struct TMDBReleaseDateResult: Codable {
        let iso_3166_1: String
        let release_dates: [TMDBReleaseDate]
    }
    
    struct TMDBReleaseDate: Codable {
        let certification: String?
    }
    
    struct TMDBMovieCredits: Codable {
        let crew: [TMDBPerson]?
        let cast: [TMDBPerson]?
    }
    
    struct TMDBPerson: Codable {
        let id: Int
        let name: String
        let character: String?
        let profile_path: String?
        let job: String?
    }
    
    func cleanTitle(_ title: String) -> String {
        // Remove year in parentheses for better TMDB matching
        var cleaned = title
        let yearPattern = #"\s*\(\d{4}\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: yearPattern) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    func searchMovie(title: String, year: Int? = nil) async throws -> TMDBMovie? {
        let cleanedTitle = cleanTitle(title)
        let encodedTitle = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanedTitle
        var urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedTitle)&language=en-US"
        
        if let year = year {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        // Try to extract year from original title for better matching
        let yearPattern = #"\((\d{4})\)"#
        var searchYear: Int? = year
        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           match.numberOfRanges > 1,
           let yearRange = Range(match.range(at: 1), in: title),
           let extractedYear = Int(String(title[yearRange])) {
            searchYear = extractedYear
        }
        
        // Find best match - exact title match preferred, then by year if available
        let exactMatch = response.results.first { movie in
            movie.title.lowercased() == cleanedTitle.lowercased()
        }
        
        if let exactMatch = exactMatch {
            return exactMatch
        }
        
        // Try matching by year if we have one
        if let searchYear = searchYear {
            let yearMatch = response.results.first { movie in
                if let releaseDate = movie.release_date, let movieYear = Int(releaseDate.prefix(4)) {
                    return abs(movieYear - searchYear) <= 1 // Allow 1 year difference
                }
                return false
            }
            if let yearMatch = yearMatch {
                return yearMatch
            }
        }
        
        return response.results.first
    }
    
    func getMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
        let urlString = "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)&append_to_response=release_dates&language=en-US"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try? JSONDecoder().decode(TMDBMovieDetails.self, from: data)
    }
    
    func getMovieCredits(tmdbId: Int) async throws -> TMDBMovieCredits? {
        let urlString = "\(baseURL)/movie/\(tmdbId)/credits?api_key=\(apiKey)&language=en-US"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try? JSONDecoder().decode(TMDBMovieCredits.self, from: data)
    }
}

// MARK: - Main Function

func addRTLists() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Adding RT Essential Movies for Kids and RT Best Christmas Movies\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded existing bootstrap data")
    print("   Sources: \(bootstrapData.dataSources.count)")
    print("   Movies: \(bootstrapData.movies.count)")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    // Configure lists to add
    let listsToAdd: [MovieListConfig] = [
        MovieListConfig(
            identifier: "rt-kids",
            name: "RT: Essential Movies for Kids",
            url: "https://editorial.rottentomatoes.com/guide/essential-movies-for-kids/",
            titles: rtKidsTitles
        ),
        MovieListConfig(
            identifier: "rt-christmas",
            name: "RT: Best Christmas Movies",
            url: "https://editorial.rottentomatoes.com/guide/best-christmas-movies/",
            titles: rtChristmasTitles
        )
    ]
    
    let tmdbService = TMDBService()
    var totalNewMovies = 0
    var totalEnriched = 0
    
    for listConfig in listsToAdd {
        print("\n" + String(repeating: "=", count: 70))
        print("📋 Processing: \(listConfig.name)")
        print(String(repeating: "=", count: 70))
        
        // Get existing titles for this source
        let existingTitles = Set(bootstrapData.movies
            .filter { $0.sourceIdentifier == listConfig.identifier }
            .map { $0.title.lowercased().trimmingCharacters(in: .whitespaces) })
        
        print("   Total titles in list: \(listConfig.titles.count)")
        print("   Existing in database: \(existingTitles.count)")
        
        // Update or create source
        var sourceIndex = bootstrapData.dataSources.firstIndex { $0.identifier == listConfig.identifier }
        if sourceIndex == nil {
            let newSource = BootstrapDataSource(
                identifier: listConfig.identifier,
                name: listConfig.name,
                type: "url",
                url: listConfig.url,
                isRankedList: true,
                movieCount: 0
            )
            bootstrapData.dataSources.append(newSource)
            sourceIndex = bootstrapData.dataSources.count - 1
        }
        
        var newMovies: [BootstrapMovie] = []
        var moviesToEnrich: [(index: Int, movie: BootstrapMovie, year: Int?)] = []
        var skippedCount = 0
        
        // Process titles
        for (rank, title) in listConfig.titles.enumerated() {
            let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Check if already exists
            if existingTitles.contains(normalizedTitle) {
                skippedCount += 1
                if skippedCount <= 3 || skippedCount % 20 == 0 {
                    print("   ⏭️  [\(rank + 1)] Skipping '\(title)' (already exists)")
                }
                continue
            }
            
            // Extract year from title if present
            var year: Int? = nil
            let yearPattern = #"\((\d{4})\)"#
            if let regex = try? NSRegularExpression(pattern: yearPattern),
               let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
               match.numberOfRanges > 1,
               let yearRange = Range(match.range(at: 1), in: title),
               let extractedYear = Int(String(title[yearRange])) {
                year = extractedYear
            }
            
            // Create base movie entry
            let movie = BootstrapMovie(
                title: title,
                sourceIdentifier: listConfig.identifier,
                rank: rank + 1,
                sourceTitle: nil,
                tmdbId: nil,
                year: year,
                posterPath: nil,
                backdropPath: nil,
                overview: nil,
                mpaaRating: nil,
                genres: nil,
                streamingServices: nil,
                credits: nil,
                trailer: nil,
                podcastEpisodeDescription: nil
            )
            
            moviesToEnrich.append((index: newMovies.count, movie: movie, year: year))
            newMovies.append(movie)
        }
        
        print("\n   ✅ Queued \(newMovies.count) new movies for enrichment")
        print("   ⏭️  Skipped \(skippedCount) existing movies")
        
        // Enrich with TMDB data
        print("\n   🎬 Enriching with TMDB data...")
        var enrichedCount = 0
        var failedCount = 0
        
        for (index, movieInfo) in moviesToEnrich.enumerated() {
            let movie = movieInfo.movie
            let displayIndex = index + 1
            
            if displayIndex % 10 == 0 || displayIndex == 1 || displayIndex == moviesToEnrich.count {
                print("      [\(displayIndex)/\(moviesToEnrich.count)] '\(movie.title)'...")
            }
            
            do {
                // Search for movie
                guard let searchResult = try await tmdbService.searchMovie(title: movie.title, year: movieInfo.year) else {
                    if displayIndex <= 5 || displayIndex % 10 == 0 {
                        print("         ⚠️  Not found in TMDB")
                    }
                    failedCount += 1
                    continue
                }
                
                // Get details
                let details = try? await tmdbService.getMovieDetails(tmdbId: searchResult.id)
                let credits = try? await tmdbService.getMovieCredits(tmdbId: searchResult.id)
                
                // Update movie
                newMovies[movieInfo.index].tmdbId = searchResult.id
                newMovies[movieInfo.index].posterPath = details?.poster_path ?? searchResult.poster_path
                newMovies[movieInfo.index].backdropPath = details?.backdrop_path ?? searchResult.backdrop_path
                newMovies[movieInfo.index].overview = details?.overview ?? searchResult.overview
                
                // Use year from details if available, otherwise keep extracted year
                if let releaseDate = details?.release_date ?? searchResult.release_date,
                   let releaseYear = Int(releaseDate.prefix(4)) {
                    newMovies[movieInfo.index].year = releaseYear
                }
                
                // MPAA rating
                if let mpaa = details?.mpaaRating {
                    newMovies[movieInfo.index].mpaaRating = mpaa
                }
                
                // Genres
                if let genres = details?.genres {
                    newMovies[movieInfo.index].genres = genres.map { $0.name }
                }
                
                // Credits
                if let creditsData = credits {
                    let director = creditsData.crew?.first { $0.job == "Director" }?.name
                    let cast = creditsData.cast?.prefix(5).map { member in
                        BootstrapCastMember(
                            id: member.id,
                            name: member.name,
                            character: member.character,
                            profilePath: member.profile_path
                        )
                    }
                    newMovies[movieInfo.index].credits = BootstrapCredits(
                        director: director,
                        cast: cast
                    )
                }
                
                enrichedCount += 1
                if displayIndex <= 5 || displayIndex % 10 == 0 {
                    print("         ✅ Enriched (TMDB ID: \(searchResult.id))")
                }
                
                // Rate limiting
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
                
            } catch {
                if displayIndex <= 5 || displayIndex % 10 == 0 {
                    print("         ❌ Error: \(error.localizedDescription)")
                }
                failedCount += 1
            }
        }
        
        // Add all movies to bootstrap data
        bootstrapData.movies.append(contentsOf: newMovies)
        
        // Update source count
        if let index = sourceIndex {
            bootstrapData.dataSources[index].movieCount = listConfig.titles.count
        }
        
        totalNewMovies += newMovies.count
        totalEnriched += enrichedCount
        
        print("\n   ✅ Completed \(listConfig.name)")
        print("      New movies added: \(newMovies.count)")
        print("      Enriched: \(enrichedCount)")
        print("      Failed: \(failedCount)")
    }
    
    // Update generated date
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Save
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING UPDATED DATA")
    print(String(repeating: "=", count: 70))
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Total Movies: \(bootstrapData.movies.count)")
        print("   New Movies Added: \(totalNewMovies)")
        print("   Total Enriched: \(totalEnriched)")
        
        // Show source counts
        for listConfig in listsToAdd {
            if let source = bootstrapData.dataSources.first(where: { $0.identifier == listConfig.identifier }) {
                print("   \(source.name): \(source.movieCount) movies")
            }
        }
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await addRTLists()
    exit(0)
}

RunLoop.main.run()

