#!/usr/bin/env swift

import Foundation

/// Script to add all 403 IMDb Auteur films to bootstrap_data.json and enrich with TMDB data

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

// MARK: - IMDb Auteur List (all 403 titles in order)

let imdbAuteurTitles = [
    "Reservoir Dogs", "Pulp Fiction", "Jackie Brown", "Kill Bill: Vol. 1", "Kill Bill: Vol. 2",
    "Inglourious Basterds", "Django Unchained", "The Hateful Eight", "Shaun of the Dead", "Hot Fuzz",
    "Scott Pilgrim vs. the World", "The World's End", "Baby Driver", "Following", "Memento",
    "Batman Begins", "The Prestige", "The Dark Knight", "Inception", "The Dark Knight Rises",
    "Interstellar", "Dunkirk", "Hard Eight", "Boogie Nights", "Punch-Drunk Love",
    "There Will Be Blood", "The Master", "Inherent Vice", "Thief", "Heat",
    "Collateral", "Paths of Glory", "Spartacus", "Lolita", "Dr. Strangelove or: How I Learned to Stop Worrying and Love the Bomb",
    "2001: A Space Odyssey", "A Clockwork Orange", "The Shining", "Eyes Wide Shut", "Full Metal Jacket",
    "The Killing", "The Godfather", "The Godfather Part II", "The Conversation", "Apocalypse Now",
    "McCabe & Mrs. Miller", "The Long Goodbye", "The Player", "Mean Streets", "Taxi Driver",
    "Raging Bull", "The King of Comedy", "Goodfellas", "Casino", "Gangs of New York",
    "The Aviator", "The Departed", "The Wolf of Wall Street", "Silence", "Drunken Angel",
    "Rashomon", "Seven Samurai", "Throne of Blood", "The Hidden Fortress", "Yojimbo",
    "Sanjuro", "High and Low", "Kagemusha: The Shadow Warrior", "Ran", "Harakiri",
    "Samurai Rebellion", "Sansho the Bailiff", "Ugetsu", "Sunset Boulevard", "The Lost Weekend",
    "Raising Arizona", "Miller's Crossing", "Barton Fink", "Fargo", "The Big Lebowski",
    "O Brother, Where Art Thou?", "No Country for Old Men", "Burn After Reading", "True Grit", "Inside Llewyn Davis",
    "Hail, Caesar!", "The Ballad of Buster Scruggs", "A Fistful of Dollars", "For a Few Dollars More", "The Good, the Bad and the Ugly",
    "Once Upon a Time in the West", "Citizen Kane", "The Lady from Shanghai", "Touch of Evil", "The Trial",
    "F for Fake", "Monty Python and the Holy Grail", "Time Bandits", "Monty Python's The Meaning of Life", "12 Monkeys",
    "Fear and Loathing in Las Vegas", "Rear Window", "Vertigo", "Psycho", "Se7en",
    "Fight Club", "Zodiac", "The Social Network", "The Girl with the Dragon Tattoo", "Gone Girl",
    "High Plains Drifter", "Unforgiven", "Gran Torino", "Changeling", "American Sniper",
    "The Mule", "12 Angry Men", "Serpico", "Dog Day Afternoon", "Network",
    "The Bridge on the River Kwai", "Lawrence of Arabia", "Lock, Stock and Two Smoking Barrels", "Snatch", "Revolver",
    "RocknRolla", "Sherlock Holmes", "Sherlock Holmes: A Game of Shadows", "King Arthur: Legend of the Sword", "Whiplash",
    "La La Land", "Drive", "Only God Forgives", "Birdman or (The Unexpected Virtue of Ignorance)", "The Revenant",
    "Gravity", "Children of Men", "Y tu mamá también", "Mad Max", "The Road Warrior",
    "Mad Max Beyond Thunderdome", "Mad Max: Fury Road", "Pi", "Requiem for a Dream", "The Fountain",
    "Black Swan", "Mother!", "Bottle Rocket", "Fantastic Mr. Fox", "Moonrise Kingdom",
    "Isle of Dogs", "Before the Devil Knows You're Dead", "In Bruges", "Seven Psychopaths", "Three Billboards Outside Ebbing, Missouri",
    "Playtime", "Dazed and Confused", "Slacker", "School of Rock", "Climax",
    "The Outlaw Josey Wales", "Anima", "Kiss Kiss Bang Bang", "The Nice Guys", "Once Upon a Time… in Hollywood",
    "Ocean's Eleven", "Ocean's Twelve", "Ocean's Thirteen", "Logan Lucky", "The Graduate",
    "Waking Life", "A Scanner Darkly", "Spirited Away", "Princess Mononoke", "Lupin III: The Castle of Cagliostro",
    "Aguirre, the Wrath of God", "Panic Room", "Parasite", "Snowpiercer", "Terminator 2: Judgment Day",
    "The Terminator", "Titanic", "The Terminal", "War of the Worlds", "Minority Report",
    "Saving Private Ryan", "Schindler's List", "Jurassic Park", "Indiana Jones and the Temple of Doom", "Raiders of the Lost Ark",
    "E.T. the Extra-Terrestrial", "Jaws", "Indiana Jones and the Last Crusade", "Chinatown", "The Irishman",
    "Edge of Tomorrow", "The Bourne Identity", "American Made", "Marriage Story", "The Meyerowitz Stories",
    "The Untouchables", "Scarface", "1917", "Skyfall", "American Beauty",
    "Uncut Gems", "Good Time", "Mission: Impossible", "Blow Out", "Boyhood",
    "Magnolia", "Looper", "Knives Out", "House of Games", "The Getaway",
    "Sexy Beast", "Under the Skin", "The Lighthouse", "The Friends of Eddie Coyle", "Bullitt",
    "Duck, You Sucker!", "Heist", "Badlands", "Traffic", "Out of Sight",
    "The Witch", "Before Sunrise", "Insomnia", "Coogan's Bluff", "Snowden",
    "The Doors", "Midnight Cowboy", "The Big Short", "Shadow", "Molly's Game",
    "Platoon", "Natural Born Killers", "The Italian Job", "Straight Outta Compton", "Law Abiding Citizen",
    "Sicario", "Sin City", "Once Upon a Time in Mexico", "Desperado", "El Mariachi",
    "City of God", "Cool Hand Luke", "One Flew Over the Cuckoo's Nest", "The Gentlemen", "The Verdict",
    "The Breakfast Club", "The Outsiders", "Crossroads", "The Warriors", "The Apartment",
    "Pirates", "Double Indemnity", "Bob le Flambeur", "To Be or Not to Be", "Rumble Fish",
    "Lady Bird", "Days of Heaven", "The Fly", "Shivers", "Cape Fear",
    "Da 5 Bloods", "Midsommar", "Hereditary", "On the Waterfront", "A Cop",
    "Exotica", "Speaking Parts", "The Sweet Hereafter", "Ararat", "The Adjuster",
    "21 Grams", "Gone Baby Gone", "Unstoppable", "True Romance", "The Thin Red Line",
    "Knight of Cups", "The Ladykillers", "Blazing Saddles", "Tenet", "The Brothers Bloom",
    "The Man Who Wasn't There", "Catch Me If You Can", "Almost Famous", "The Treasure of the Sierra Madre", "Come and See",
    "Tommy", "Altered States", "Confidence", "Glengarry Glen Ross", "Death Proof",
    "Rosemary's Baby", "Day for Night", "The 400 Blows", "American Hustle", "Silver Linings Playbook",
    "The Fighter", "The Color of Money", "Ace in the Hole", "Sabrina", "California Split",
    "Nashville", "The Asphalt Jungle", "The Seven Year Itch", "Alien", "A Face in the Crowd",
    "They Live", "The Thing", "Jerry Maguire", "The Anderson Tapes", "Once Upon a Time in America",
    "True Lies", "Blood Simple", "The Hot Rock", "Stand by Me", "Drugstore Cowboy",
    "Good Will Hunting", "Layer Cake", "Kingsman: The Secret Service", "Escape from Alcatraz", "Dirty Harry",
    "Band of Outsiders", "Carlito's Way", "On the Rocks", "This Is Spinal Tap", "Le Samouraï",
    "Rolling Thunder", "The Outfit", "Apocalypto", "The Godfather Part III", "The Hurt Locker",
    "Big Trouble in Little China", "Aliens", "Django", "Free Fire", "High-Rise",
    "Wrath of Man", "Top Gun", "Croupier", "Get Carter", "Nausicaä of the Valley of the Wind",
    "Howl's Moving Castle", "No Sudden Move", "The Wild Bunch", "Dead Alive", "A Better Tomorrow",
    "The Big Sleep", "Duel", "Stranger Than Paradise", "The Game", "Drunken Master II",
    "The Card Counter", "The Fisher King", "The Pope of Greenwich Village", "Dune: Part One", "Last Night in Soho",
    "Star Trek Into Darkness", "Star Trek", "tick, tick... BOOM!", "Thelma & Louise", "Mulholland Drive",
    "Eraserhead", "Jojo Rabbit", "What We Do in the Shadows", "Thor: Ragnarok", "The Other Guys",
    "Don't Look Up", "Licorice Pizza", "Nightmare Alley", "Solaris", "Escape from New York",
    "The Man from U.N.C.L.E.", "The Northman", "Pusher", "Hard Boiled", "The Strange Thing About the Johnsons",
    "Femme Fatale", "Amsterdam", "Glass Onion", "Ben-Hur", "Amadeus",
    "The Elephant Man", "The Banshees of Inisherin", "Avatar", "Avatar: The Way of Water", "Ghost Dog: The Way of the Samurai",
    "Enemy", "Babylon", "Memories of Murder", "Beau Is Afraid", "Castle in the Sky",
    "Mystic River", "The Great Silence", "After Hours", "Oppenheimer", "The People vs. Larry Flynt",
    "Gladiator", "Gosford Park", "The Last Picture Show"
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
    
    func searchMovie(title: String) async throws -> TMDBMovie? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedTitle)&language=en-US"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        // Find best match - try exact first, then first result
        let exactMatch = response.results.first { $0.title.lowercased() == title.lowercased() }
        return exactMatch ?? response.results.first
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

func addIMDbAuteurList() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Adding IMDb Auteur List (403 films)\n")
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
    
    // Get existing titles for imdb-list-1 source
    let existingTitles = Set(bootstrapData.movies
        .filter { $0.sourceIdentifier == "imdb-list-1" }
        .map { $0.title.lowercased().trimmingCharacters(in: .whitespaces) })
    
    print("\n📋 Processing \(imdbAuteurTitles.count) IMDb Auteur titles...")
    print("   Existing in database: \(existingTitles.count)")
    
    // Update or create imdb-list-1 source
    var sourceIndex = bootstrapData.dataSources.firstIndex { $0.identifier == "imdb-list-1" }
    if sourceIndex == nil {
        let newSource = BootstrapDataSource(
            identifier: "imdb-list-1",
            name: "IMDB Auteurs",
            type: "url",
            url: "https://www.imdb.com/list/ls042702401/",
            isRankedList: true,
            movieCount: 0
        )
        bootstrapData.dataSources.append(newSource)
        sourceIndex = bootstrapData.dataSources.count - 1
    }
    
    var newMovies: [BootstrapMovie] = []
    var moviesToEnrich: [(index: Int, movie: BootstrapMovie)] = []
    var skippedCount = 0
    
    let tmdbService = TMDBService()
    
    for (rank, title) in imdbAuteurTitles.enumerated() {
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if already exists
        if existingTitles.contains(normalizedTitle) {
            skippedCount += 1
            if skippedCount <= 5 || skippedCount % 50 == 0 {
                print("   ⏭️  [\(rank + 1)] Skipping '\(title)' (already exists)")
            }
            continue
        }
        
        if (rank + 1) % 50 == 0 {
            print("   📽️  Processing [\(rank + 1)/403]...")
        }
        
        // Create base movie entry
        let movie = BootstrapMovie(
            title: title,
            sourceIdentifier: "imdb-list-1",
            rank: rank + 1,
            sourceTitle: nil,
            tmdbId: nil,
            year: nil,
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
        
        moviesToEnrich.append((index: newMovies.count, movie: movie))
        newMovies.append(movie)
    }
    
    print("\n✅ Added \(newMovies.count) new movies to queue")
    print("   Skipped \(skippedCount) existing movies")
    
    // Enrich with TMDB data
    print("\n" + String(repeating: "=", count: 70))
    print("🎬 ENRICHING WITH TMDB DATA")
    print(String(repeating: "=", count: 70))
    
    var enrichedCount = 0
    var failedCount = 0
    
    for (index, movieInfo) in moviesToEnrich.enumerated() {
        let movie = movieInfo.movie
        let displayIndex = index + 1
        
        if displayIndex % 25 == 0 || displayIndex == 1 || displayIndex == moviesToEnrich.count {
            print("\n[\(displayIndex)/\(moviesToEnrich.count)] Enriching '\(movie.title)'...")
        }
        
        do {
            // Search for movie
            guard let searchResult = try await tmdbService.searchMovie(title: movie.title) else {
                if displayIndex <= 5 || displayIndex % 25 == 0 {
                    print("   ⚠️  Not found in TMDB")
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
            
            // Extract year
            if let releaseDate = details?.release_date ?? searchResult.release_date,
               let year = Int(releaseDate.prefix(4)) {
                newMovies[movieInfo.index].year = year
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
            
            if displayIndex <= 5 || displayIndex % 25 == 0 {
                print("   ✅ Enriched (TMDB ID: \(searchResult.id))")
            }
            
            // Rate limiting - 0.25 seconds between requests
            try? await Task.sleep(nanoseconds: 250_000_000)
            
        } catch {
            if displayIndex <= 5 || displayIndex % 25 == 0 {
                print("   ❌ Error: \(error.localizedDescription)")
            }
            failedCount += 1
        }
    }
    
    // Add all movies to bootstrap data
    bootstrapData.movies.append(contentsOf: newMovies)
    
    // Update source count
    if let index = sourceIndex {
        bootstrapData.dataSources[index].movieCount = imdbAuteurTitles.count
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
        print("   New Movies Added: \(newMovies.count)")
        print("   Movies Enriched: \(enrichedCount)")
        print("   Movies Failed: \(failedCount)")
        print("   IMDb Auteur Source: \(bootstrapData.dataSources.first { $0.identifier == "imdb-list-1" }?.movieCount ?? 0) movies")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await addIMDbAuteurList()
    exit(0)
}

RunLoop.main.run()

