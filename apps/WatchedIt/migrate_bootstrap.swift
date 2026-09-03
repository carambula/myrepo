#!/usr/bin/env swift
//
//  migrate_bootstrap.swift
//  WatchedIt
//
//  Script to export bootstrap data from new relational structure
//

import Foundation

// This script would be run from within the app context
// For now, it's a reference implementation

struct BootstrapExporter {
    static func exportBootstrap(from movies: [Movie]) -> [BootstrapEpisode] {
        return movies.compactMap { movie -> BootstrapEpisode? in
            guard let podcastEpisode = movie.podcastEpisode else { return nil }
            
            let cast = movie.credits?.cast.map { member in
                BootstrapCastMember(
                    id: member.id,
                    name: member.name,
                    character: member.character,
                    profilePath: member.profilePath
                )
            }
            
            let trailer = movie.trailer.map { trailer in
                BootstrapTrailer(
                    id: trailer.id,
                    name: trailer.name,
                    youtubeKey: trailer.youtubeKey,
                    isOfficial: trailer.isOfficial
                )
            }
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            let publishDateString = podcastEpisode.publishDate.map { formatter.string(from: $0) }
            
            return BootstrapEpisode(
                title: podcastEpisode.title,
                movieTitle: movie.title,
                publishDate: publishDateString,
                guid: podcastEpisode.episodeId,
                description: podcastEpisode.description,
                year: movie.year,
                genres: movie.genres.isEmpty ? nil : movie.genres,
                rtScore: movie.rtScore,
                mpaaRating: movie.mpaaRating,
                tmdbId: movie.tmdbId,
                overview: movie.overview,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                director: movie.credits?.director,
                cast: cast,
                applePodcastsUrl: podcastEpisode.applePodcastsUrl,
                spotifyUrl: podcastEpisode.spotifyUrl,
                trailer: trailer
            )
        }
    }
}

// Note: This script is a reference. The actual bootstrap export would be done
// through the app's LocalDatabaseManager which can export movies to bootstrap format

