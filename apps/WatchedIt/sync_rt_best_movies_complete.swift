#!/usr/bin/env swift

import Foundation

/// Script to sync RT Best Movies list with the complete list of 300 movies

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

struct BootstrapDataSource: Codable {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isRankedList: Bool
    var movieCount: Int
}

// Complete list of 300 movies
let completeList: [(rank: Int, title: String, year: Int)] = [
    (1, "The Godfather", 1972),
    (2, "Seven Samurai", 1954),
    (3, "Casablanca", 1942),
    (4, "Rear Window", 1954),
    (5, "L.A. Confidential", 1997),
    (6, "On the Waterfront", 1954),
    (7, "Chinatown", 1974),
    (8, "Modern Times", 1936),
    (9, "The Battle of Algiers", 1966),
    (10, "Schindler's List", 1993),
    (11, "12 Angry Men", 1957),
    (12, "All About Eve", 1950),
    (13, "Parasite", 2019),
    (14, "Singin' in the Rain", 1952),
    (15, "Stop Making Sense", 1984),
    (16, "Sunset Boulevard", 1950),
    (17, "Toy Story", 1995),
    (18, "The Third Man", 1949),
    (19, "Toy Story 2", 1999),
    (20, "Top Gun: Maverick", 2022),
    (21, "Star Wars: Episode IV – A New Hope", 1977),
    (22, "Godzilla Minus One", 2023),
    (23, "Cool Hand Luke", 1967),
    (24, "The Philadelphia Story", 1940),
    (25, "How to Train Your Dragon", 2010),
    (26, "M", 1931),
    (27, "Citizen Kane", 1941),
    (28, "The Godfather, Part II", 1974),
    (29, "Three Colors: Red", 1994),
    (30, "The Decalogue", 1989),
    (31, "A Separation", 2011),
    (32, "The Kid", 1921),
    (33, "Summer of Soul", 2021),
    (34, "Toy Story 3", 2010),
    (35, "Finding Nemo", 2003),
    (36, "Dr. Strangelove", 1964),
    (37, "Still: A Michael J. Fox Movie", 2023),
    (38, "Sinners", 2025),
    (39, "Up", 2009),
    (40, "The Wages of Fear", 1953),
    (41, "The Maltese Falcon", 1941),
    (42, "Spotlight", 2015),
    (43, "The Wrestler", 2008),
    (44, "Grave of the Fireflies", 1988),
    (45, "North by Northwest", 1959),
    (46, "Psycho", 1960),
    (47, "Bicycle Thieves", 1948),
    (48, "Spider-Man: Into the Spider-Verse", 2018),
    (49, "The Wizard of Oz", 1939),
    (50, "The Father", 2020),
    (51, "It Happened One Night", 1934),
    (52, "Spirited Away", 2001),
    (53, "The Treasure of the Sierra Madre", 1948),
    (54, "The 400 Blows", 1959),
    (55, "Zootopia", 2016),
    (56, "Double Indemnity", 1944),
    (57, "Annie Hall", 1977),
    (58, "Man on Wire", 2008),
    (59, "Wallace & Gromit: Vengeance Most Fowl", 2024),
    (60, "Coco", 2017),
    (61, "The Wild Robot", 2024),
    (62, "Inside Out", 2015),
    (63, "The Sorrow and the Pity", 1969),
    (64, "Shoplifters", 2018),
    (65, "Kind Hearts and Coronets", 1949),
    (66, "Tampopo", 1985),
    (67, "Mission: Impossible – Fallout", 2018),
    (68, "Witness for the Prosecution", 1957),
    (69, "Tokyo Story", 1953),
    (70, "Before Sunrise", 1995),
    (71, "Jaws", 1975),
    (72, "Wolfwalkers", 2020),
    (73, "Nights of Cabiria", 1957),
    (74, "The Good, the Bad and the Ugly", 1966),
    (75, "Alien", 1979),
    (76, "Selma", 2014),
    (77, "I'm Still Here", 2024),
    (78, "Metropolis", 1927),
    (79, "Are You There God? It's Me, Margaret.", 2023),
    (80, "A Man Escaped", 1956),
    (81, "Paddington 2", 2017),
    (82, "All About My Mother", 1999),
    (83, "Fanny and Alexander", 1982),
    (84, "The Last Picture Show", 1971),
    (85, "Pather Panchali", 1955),
    (86, "Stalker", 1979),
    (87, "A Hard Day's Night", 1964),
    (88, "Minding the Gap", 2018),
    (89, "Laura", 1944),
    (90, "Let the Right One In", 2008),
    (91, "No Other Land", 2024),
    (92, "Crip Camp", 2020),
    (93, "The Best Years of Our Lives", 1946),
    (94, "All Quiet on the Western Front", 1930),
    (95, "The Shop Around the Corner", 1940),
    (96, "Rome, Open City", 1945),
    (97, "Ikiru", 1952),
    (98, "His Girl Friday", 1940),
    (99, "Knives Out", 2019),
    (100, "The Gold Rush", 1925),
    (101, "Short Term 12", 2013),
    (102, "Anatomy of a Murder", 1959),
    (103, "Ghostlight", 2024),
    (104, "Apollo 11", 2019),
    (105, "Super/Man: The Christopher Reeve Story", 2024),
    (106, "Your Name", 2016),
    (107, "They Shall Not Grow Old", 2018),
    (108, "La Strada", 1954),
    (109, "The Holdovers", 2023),
    (110, "Won't You Be My Neighbor?", 2018),
    (111, "The Lord of the Rings: The Two Towers", 2002),
    (112, "The Terminator", 1984),
    (113, "Sanjuro", 1962),
    (114, "Rebecca", 1940),
    (115, "Inside Job", 2010),
    (116, "Night and Fog", 1955),
    (117, "The Seed of the Sacred Fig", 2024),
    (118, "Shadow of a Doubt", 1943),
    (119, "Goldfinger", 1964),
    (120, "Murderball", 2005),
    (121, "High and Low", 1963),
    (122, "Woman in the Dunes", 1964),
    (123, "The Lady Eve", 1941),
    (124, "The Last Waltz", 1978),
    (125, "Ali: Fear Eats the Soul", 1974),
    (126, "Ugetsu", 1953),
    (127, "Get Out", 2017),
    (128, "Army of Shadows", 1969),
    (129, "Portrait of a Lady on Fire", 2019),
    (130, "The Big Sick", 2017),
    (131, "The Adventures of Robin Hood", 1938),
    (132, "Anvil! The Story of Anvil", 2008),
    (133, "Good Will Hunting", 1997),
    (134, "Maiden", 2018),
    (135, "I Am Cuba", 1964),
    (136, "The Passion of Joan of Arc", 1928),
    (137, "Argo", 2012),
    (138, "Crouching Tiger, Hidden Dragon", 2000),
    (139, "The Silence of the Lambs", 1991),
    (140, "Goodfellas", 1990),
    (141, "Collective", 2019),
    (142, "Safety Last", 1923),
    (143, "Toy Story 4", 2019),
    (144, "Mr. Smith Goes to Washington", 1939),
    (145, "The Pianist", 2002),
    (146, "My Life as a Zucchini", 2016),
    (147, "The Ascent", 1977),
    (148, "Mad Max: Fury Road", 2015),
    (149, "Faces Places", 2017),
    (150, "Minari", 2020),
    (151, "BlackBerry", 2023),
    (152, "The Lavender Hill Mob", 1951),
    (153, "Das Boot", 1981),
    (154, "Once", 2007),
    (155, "The Dark Knight", 2008),
    (156, "Ivan's Childhood", 1963),
    (157, "Rashomon", 1950),
    (158, "Kes", 1969),
    (159, "Wadjda", 2012),
    (160, "Beauty and the Beast", 1991),
    (161, "Top Hat", 1935),
    (162, "Mission: Impossible – Dead Reckoning Part One", 2023),
    (163, "Sansho the Bailiff", 1954),
    (164, "Marcel the Shell with Shoes On", 2021),
    (165, "Spider-Man: Across the Spider-Verse", 2023),
    (166, "When We Were Kings", 1996),
    (167, "Life Itself", 2014),
    (168, "The Bridge on the River Kwai", 1957),
    (169, "Woodstock", 1970),
    (170, "Winter Soldier", 1972),
    (171, "Harry Potter and the Deathly Hallows: Part 2", 2011),
    (172, "Waltz With Bashir", 2008),
    (173, "Raiders of the Lost Ark", 1981),
    (174, "Through a Glass Darkly", 1961),
    (175, "Hamilton", 2020),
    (176, "Honeyland", 2019),
    (177, "The Red Shoes", 1948),
    (178, "The Promised Land", 2023),
    (179, "Corpus Christi", 2019),
    (180, "Children of Paradise", 1945),
    (181, "The King of Kong: A Fistful of Quarters", 2007),
    (182, "The Fog of War", 2003),
    (183, "Blackfish", 2013),
    (184, "Harlan County, U.S.A.", 1976),
    (185, "Sound of Metal", 2019),
    (186, "Flow", 2024),
    (187, "The Rescue", 2021),
    (188, "Hunt for the Wilderpeople", 2016),
    (189, "Flee", 2021),
    (190, "Hoop Dreams", 1994),
    (191, "Tower", 2016),
    (192, "Capturing the Friedmans", 2003),
    (193, "The Mirror", 1975),
    (194, "Meet Me in St. Louis", 1944),
    (195, "Mr. Death: The Rise and Fall of Fred A. Leuchter, Jr.", 1999),
    (196, "Ordet", 1955),
    (197, "The Conformist", 1970),
    (198, "Strangers on a Train", 1951),
    (199, "Free Solo", 2018),
    (200, "Ran", 1985),
    (201, "Sing Sing", 2023),
    (202, "Sunrise", 1927),
    (203, "76 Days", 2020),
    (204, "Aladdin", 1992),
    (205, "The Social Network", 2010),
    (206, "In the Heat of the Night", 1967),
    (207, "Eighth Grade", 2018),
    (208, "Late Spring", 1949),
    (209, "Paths of Glory", 1957),
    (210, "Persepolis", 2007),
    (211, "Sullivan's Travels", 1941),
    (212, "For Sama", 2019),
    (213, "Hell or High Water", 2016),
    (214, "Saving Private Ryan", 1998),
    (215, "Monsters, Inc.", 2001),
    (216, "Angels With Dirty Faces", 1938),
    (217, "The Quiet Girl", 2022),
    (218, "The Cameraman", 1928),
    (219, "Sweet Smell of Success", 1957),
    (220, "12 Years a Slave", 2013),
    (221, "King Kong", 1933),
    (222, "L'Atalante", 1934),
    (223, "Day of Wrath", 1943),
    (224, "Captain Blood", 1935),
    (225, "Quai des Orfevres", 1947),
    (226, "Pan's Labyrinth", 2006),
    (227, "A Fistful of Dollars", 1964),
    (228, "The Iron Giant", 1999),
    (229, "Dog Day Afternoon", 1975),
    (230, "The Grapes of Wrath", 1940),
    (231, "The Endless Summer", 1966),
    (232, "Lady Bird", 2017),
    (233, "Halloween", 1978),
    (234, "Unforgiven", 1992),
    (235, "Brooklyn", 2015),
    (236, "Catch Me If You Can", 2002),
    (237, "I Vitelloni", 1953),
    (238, "I Am Not Your Negro", 2016),
    (239, "Memento", 2000),
    (240, "The Insider", 1999),
    (241, "Monster", 2023),
    (242, "The Thin Man", 1934),
    (243, "Love and Death", 1975),
    (244, "La Haine", 1995),
    (245, "Forbidden Games", 1952),
    (246, "The Lost Weekend", 1945),
    (247, "The Killers", 1946),
    (248, "Star Trek", 2009),
    (249, "The Fallen Idol", 1948),
    (250, "Jalsaghar", 1960),
    (251, "Black Narcissus", 1947),
    (252, "Ratatouille", 2007),
    (253, "Maria Full of Grace", 2004),
    (254, "Life of Brian", 1979),
    (255, "Holiday", 1938),
    (256, "Guillermo del Toro's Pinocchio", 2022),
    (257, "Whiplash", 2014),
    (258, "Battleship Potemkin", 1925),
    (259, "Make Way for Tomorrow", 1937),
    (260, "Quiz Show", 1994),
    (261, "Salesman", 1969),
    (262, "Spider-Man: No Way Home", 2021),
    (263, "WALL-E", 2008),
    (264, "The Princess Bride", 1987),
    (265, "The Farewell", 2019),
    (266, "Simon of the Desert", 1965),
    (267, "Grand Illusion", 1937),
    (268, "Suzume", 2022),
    (269, "Au Hasard Balthazar", 1966),
    (270, "Umberto D", 1952),
    (271, "A Night to Remember", 1958),
    (272, "The Handmaiden", 2016),
    (273, "The Band's Visit", 2007),
    (274, "The Mitchells vs. the Machines", 2021),
    (275, "Touch of Evil", 1958),
    (276, "Star Wars: Episode V – The Empire Strikes Back", 1980),
    (277, "Stray Dog", 1949),
    (278, "Once Upon a Time in the West", 1968),
    (279, "The Discreet Charm of the Bourgeoisie", 1972),
    (280, "BPM (Beats Per Minute)", 2017),
    (281, "The King's Speech", 2010),
    (282, "Brazil", 1985),
    (283, "Local Hero", 1983),
    (284, "The Red Circle", 1970),
    (285, "I Was Born, But...", 1932),
    (286, "Pulp Fiction", 1994),
    (287, "The French Connection", 1971),
    (288, "Robot Dreams", 2023),
    (289, "Aliens", 1986),
    (290, "Yojimbo", 1961),
    (291, "Playtime", 1967),
    (292, "My Left Foot", 1989),
    (293, "8 1/2", 1963),
    (294, "Sling Blade", 1996),
    (295, "God's Own Country", 2017),
    (296, "Eternal Sunshine of the Spotless Mind", 2004),
    (297, "Dolemite Is My Name", 2019),
    (298, "The Ladykillers", 1955),
    (299, "Leave No Trace", 2018),
    (300, "One Flew Over the Cuckoo's Nest", 1975)
]

// TMDB Service
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
    
    func searchMovie(title: String, year: Int) async throws -> TMDBMovie? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        var urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedTitle)&language=en-US"
        
        // Add year for better matching
        if year > 1900 && year <= 2025 {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        // Find best match by year
        let yearMatch = response.results.first { movie in
            if let releaseDate = movie.release_date, let movieYear = Int(releaseDate.prefix(4)) {
                return abs(movieYear - year) <= 1
            }
            return false
        }
        
        return yearMatch ?? response.results.first
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

func syncRTBestMoviesComplete() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Syncing RT Best Movies with Complete List (300 movies)\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded existing bootstrap data")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    // Get all RT Best Movies
    let rtMovies = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    print("   Found \(rtMovies.count) existing RT Best Movies entries")
    
    // Helper function to match movies
    func matchesMovie(_ movie: BootstrapMovie, title: String, year: Int) -> Bool {
        let movieTitle = movie.title.lowercased()
        let targetTitle = title.lowercased()
        
        // Check if titles match (allowing for variations)
        let titleMatches = movieTitle.contains(targetTitle) || targetTitle.contains(movieTitle) ||
                          movieTitle.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "–", with: "-") == targetTitle.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "–", with: "-")
        
        // Year should match exactly, or be very close
        let yearMatches = movie.year == year || (movie.year == nil && abs((movie.year ?? 0) - year) <= 2)
        
        return titleMatches && (movie.year == year || movie.year == nil)
    }
    
    var moviesToAdd: [BootstrapMovie] = []
    var moviesToUpdate: [(index: Int, rank: Int)] = []
    var moviesToProcess: [(movie: BootstrapMovie, rank: Int, year: Int, needsEnrichment: Bool)] = []
    
    print("\n" + String(repeating: "=", count: 70))
    print("📋 ANALYZING COMPLETE LIST")
    print(String(repeating: "=", count: 70))
    
    for item in completeList {
        let existing = rtMovies.first { matchesMovie($0, title: item.title, year: item.year) }
        
        if let existing = existing, let existingIndex = bootstrapData.movies.firstIndex(where: { $0.title == existing.title && $0.sourceIdentifier == "rt-best-all-time" && $0.year == existing.year }) {
            // Movie exists - check if rank needs updating
            if existing.rank != item.rank {
                moviesToUpdate.append((index: existingIndex, rank: item.rank))
            }
            // Check if needs enrichment
            if existing.tmdbId == nil || existing.posterPath == nil {
                moviesToProcess.append((movie: existing, rank: item.rank, year: item.year, needsEnrichment: true))
            }
        } else {
            // Movie is missing - create new entry
            let newMovie = BootstrapMovie(
                title: item.title,
                sourceIdentifier: "rt-best-all-time",
                rank: item.rank,
                sourceTitle: nil,
                tmdbId: nil,
                year: item.year,
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
            moviesToProcess.append((movie: newMovie, rank: item.rank, year: item.year, needsEnrichment: true))
            moviesToAdd.append(newMovie)
        }
    }
    
    print("\n   Movies to add: \(moviesToAdd.count)")
    print("   Ranks to update: \(moviesToUpdate.count)")
    print("   Movies needing enrichment: \(moviesToProcess.filter { $0.needsEnrichment }.count)")
    
    // Update ranks first
    for (index, rank) in moviesToUpdate {
        bootstrapData.movies[index].rank = rank
    }
    
    // Add new movies
    bootstrapData.movies.append(contentsOf: moviesToAdd)
    
    // Enrich movies with TMDB data
    let tmdbService = TMDBService()
    var enrichedCount = 0
    
    print("\n" + String(repeating: "=", count: 70))
    print("🎬 ENRICHING WITH TMDB DATA")
    print(String(repeating: "=", count: 70))
    
    for (index, item) in moviesToProcess.enumerated() {
        if !item.needsEnrichment { continue }
        
        let displayIndex = index + 1
        if displayIndex % 25 == 0 || displayIndex == 1 || displayIndex == moviesToProcess.count {
            print("\n[\(displayIndex)/\(moviesToProcess.count)] Enriching: \(item.movie.title) (\(item.year))...")
        }
        
        // Find the movie in bootstrapData
        var movieIndex: Int? = nil
        if let existingIndex = bootstrapData.movies.firstIndex(where: { $0.title == item.movie.title && $0.sourceIdentifier == "rt-best-all-time" && $0.year == item.year }) {
            movieIndex = existingIndex
        } else if let existingIndex = bootstrapData.movies.lastIndex(where: { $0.title == item.movie.title && $0.sourceIdentifier == "rt-best-all-time" }) {
            movieIndex = existingIndex
        }
        
        guard let idx = movieIndex else { continue }
        
        do {
            if let searchResult = try await tmdbService.searchMovie(title: item.movie.title, year: item.year) {
                if displayIndex % 25 == 0 || displayIndex == 1 {
                    print("   ✅ Found in TMDB (ID: \(searchResult.id))")
                }
                
                let details = try? await tmdbService.getMovieDetails(tmdbId: searchResult.id)
                let credits = try? await tmdbService.getMovieCredits(tmdbId: searchResult.id)
                
                bootstrapData.movies[idx].tmdbId = searchResult.id
                bootstrapData.movies[idx].posterPath = details?.poster_path ?? searchResult.poster_path
                bootstrapData.movies[idx].backdropPath = details?.backdrop_path ?? searchResult.backdrop_path
                bootstrapData.movies[idx].overview = details?.overview ?? searchResult.overview
                
                if let releaseDate = details?.release_date ?? searchResult.release_date,
                   let releaseYear = Int(releaseDate.prefix(4)) {
                    bootstrapData.movies[idx].year = releaseYear
                }
                
                if let mpaa = details?.mpaaRating {
                    bootstrapData.movies[idx].mpaaRating = mpaa
                }
                
                if let genres = details?.genres {
                    bootstrapData.movies[idx].genres = genres.map { $0.name }
                }
                
                if let creditsData = credits {
                    let director = creditsData.crew?.first { $0.job == "Director" }?.name
                    let cast = creditsData.cast?.prefix(5).compactMap { member -> BootstrapCastMember? in
                        BootstrapCastMember(
                            id: member.id,
                            name: member.name,
                            character: member.character,
                            profilePath: member.profile_path
                        )
                    }
                    bootstrapData.movies[idx].credits = BootstrapCredits(
                        director: director,
                        cast: cast
                    )
                }
                
                enrichedCount += 1
                try? await Task.sleep(nanoseconds: 250_000_000) // Rate limiting
                
            } else {
                if displayIndex % 25 == 0 || displayIndex == 1 {
                    print("   ⚠️  Not found in TMDB")
                }
            }
        } catch {
            if displayIndex % 25 == 0 || displayIndex == 1 {
                print("   ❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Update source count
    let rtMoviesAfter = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    if let index = bootstrapData.dataSources.firstIndex(where: { $0.identifier == "rt-best-all-time" }) {
        bootstrapData.dataSources[index].movieCount = 300
    }
    
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Save
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING")
    print(String(repeating: "=", count: 70))
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Total RT Best Movies: \(rtMoviesAfter.count)")
        print("   Added: \(moviesToAdd.count) new movies")
        print("   Updated: \(moviesToUpdate.count) ranks")
        print("   Enriched: \(enrichedCount) movies")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await syncRTBestMoviesComplete()
    exit(0)
}

RunLoop.main.run()

