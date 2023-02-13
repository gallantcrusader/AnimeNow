//  CollectionStore.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 10/28/22.
//
//

import Foundation
import OrderedCollections

// MARK: - CollectionStore

public struct CollectionStore: Hashable, Identifiable {
    public var id: Title { title }
    public var title: Title = .custom("")
    public var lastUpdated = Date()
    public var animes = OrderedSet<AnimeStore>()

    public init(
        title: CollectionStore.Title = .custom(""),
        lastUpdated: Date = Date(),
        animes: OrderedSet<AnimeStore> = OrderedSet<AnimeStore>()
    ) {
        self.title = title
        self.lastUpdated = lastUpdated
        self.animes = animes
    }

    public init() {}
}

// MARK: CollectionStore.Title

public extension CollectionStore {
    enum Title: Hashable, Codable, CaseIterable {
        public static var allCases: [CollectionStore.Title] {
            [.planning, .watching, .completed]
        }

        case planning
        case watching
        case completed
        case custom(String)

        public var value: String {
            switch self {
            case .planning:
                return "Plan to Watch"
            case .watching:
                return "Watching"
            case .completed:
                return "Completed"
            case let .custom(name):
                return name
            }
        }

        public var canDelete: Bool {
            switch self {
            case .custom:
                return true
            default:
                return false
            }
        }
    }
}
