//  CoreData+SortDescriptors.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/16/22.
//
//  Modified version of https://github.com/prisma-ai/Sworm

import Foundation

// MARK: - SortDescriptor

struct SortDescriptor: Equatable {
    let keyPathString: String
    var ascending = true
}

extension SortDescriptor {
    var object: NSSortDescriptor {
        .init(
            key: keyPathString,
            ascending: ascending
        )
    }
}

extension SortDescriptor {
    init(
        keyPath: KeyPath<some Any, some Any>,
        ascending: Bool
    ) {
        self.keyPathString = NSExpression(forKeyPath: keyPath).keyPath
        self.ascending = ascending
    }
}
