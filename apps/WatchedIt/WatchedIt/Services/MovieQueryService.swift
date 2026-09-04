//
//  MovieQueryService.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation

enum CollectionHeaderSearchScope: Equatable {
    case list(identifier: String, isRankedList: Bool)
    case movieIDs(Set<String>)
}

enum MovieQueryService {
    static func movieIdentifiers(for section: CollectionSection) -> Set<String> {
        Set(section.movies.map(\.id))
    }

    static func headerSearchMovieIDs(for section: CollectionSection) -> Set<String> {
        if let ids = section.headerSearchMovieIDs, !ids.isEmpty {
            return ids
        }
        return movieIdentifiers(for: section)
    }

    static func headerSearchScope(for section: CollectionSection) -> CollectionHeaderSearchScope? {
        if let sourceIdentifier = section.sourceIdentifier, !sourceIdentifier.isEmpty {
            return .list(identifier: sourceIdentifier, isRankedList: section.isRankedList)
        }
        let ids = headerSearchMovieIDs(for: section)
        return ids.isEmpty ? nil : .movieIDs(ids)
    }
}
