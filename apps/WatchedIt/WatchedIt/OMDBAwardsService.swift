//
//  OMDBAwardsService.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 3/15/26.
//

import Foundation

/// Service to fetch awards data from OMDB API
public class OMDBAwardsService {
    public static let shared = OMDBAwardsService()
    
    private let apiKey = "c418f9f5"
    private let baseURL = "https://www.omdbapi.com"
    
    private init() {}
    
    /// Fetch Oscar awards for a movie using IMDB ID
    public func fetchOscarAwards(imdbId: String) async throws -> OscarAwards? {
        let urlString = "\(baseURL)/?apikey=\(apiKey)&i=\(imdbId)"
        
        guard let url = URL(string: urlString) else {
            print("❌ OMDB: Invalid URL for awards: \(urlString)")
            throw URLError(.badURL)
        }
        
        print("🏆 OMDB API CALL: Fetching awards for IMDB ID \(imdbId)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OMDB: Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ OMDB: HTTP error \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let omdbResponse = try JSONDecoder().decode(OMDBMovieResponse.self, from: data)
            
            guard omdbResponse.Response == "True" else {
                print("⚠️ OMDB: Movie not found or error: \(omdbResponse.Error ?? "Unknown")")
                return nil
            }
            
            guard let awardsText = omdbResponse.Awards, !awardsText.isEmpty else {
                print("⚠️ OMDB: No awards data found for IMDB ID \(imdbId)")
                return nil
            }
            
            print("🏆 OMDB: Awards text: \"\(awardsText)\"")
            
            let oscarAwards = OscarAwards.parse(from: awardsText)
            
            if let awards = oscarAwards {
                print("✅ OMDB: Parsed Oscar awards - \(awards.totalWins) wins, \(awards.totalNominations) nominations")
            } else {
                print("⚠️ OMDB: No Oscar information found in awards text")
            }
            
            return oscarAwards
        } catch {
            print("❌ OMDB: Error fetching awards for \(imdbId): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch Oscar awards for a movie using title and year
    public func fetchOscarAwards(title: String, year: Int?) async throws -> OscarAwards? {
        var urlString = "\(baseURL)/?apikey=\(apiKey)&t=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let year = year {
            urlString += "&y=\(year)"
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ OMDB: Invalid URL for awards: \(urlString)")
            throw URLError(.badURL)
        }
        
        print("🏆 OMDB API CALL: Fetching awards for '\(title)'\(year != nil ? " (\(year!))" : "")")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ OMDB: Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ OMDB: HTTP error \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            let omdbResponse = try JSONDecoder().decode(OMDBMovieResponse.self, from: data)
            
            guard omdbResponse.Response == "True" else {
                print("⚠️ OMDB: Movie not found or error: \(omdbResponse.Error ?? "Unknown")")
                return nil
            }
            
            guard let awardsText = omdbResponse.Awards, !awardsText.isEmpty else {
                print("⚠️ OMDB: No awards data found for '\(title)'")
                return nil
            }
            
            print("🏆 OMDB: Awards text: \"\(awardsText)\"")
            
            let oscarAwards = OscarAwards.parse(from: awardsText)
            
            if let awards = oscarAwards {
                print("✅ OMDB: Parsed Oscar awards - \(awards.totalWins) wins, \(awards.totalNominations) nominations")
            } else {
                print("⚠️ OMDB: No Oscar information found in awards text")
            }
            
            return oscarAwards
        } catch {
            print("❌ OMDB: Error fetching awards for '\(title)': \(error.localizedDescription)")
            throw error
        }
    }
}

/// OMDB API Response structure
struct OMDBMovieResponse: Codable {
    let Title: String?
    let Year: String?
    let imdbID: String?
    let Awards: String?
    let Response: String
    let Error: String?
}
