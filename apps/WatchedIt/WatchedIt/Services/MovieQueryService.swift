//
//  MovieQueryService.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation

enum MovieQueryService {
    static func movieIdentifiers(for section: CollectionSection) -> Set<String> {
        Set(section.movies.map(\.id))
    }
}
