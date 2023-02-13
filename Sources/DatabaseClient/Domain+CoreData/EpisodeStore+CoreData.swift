//  EpisodeStore+CoreData.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/16/22.
//

import Foundation
import SharedModels
import Utilities

// MARK: - EpisodeStore + ManagedObjectConvertible

extension EpisodeStore: ManagedObjectConvertible {
    public static let entityName = "CDEpisodeStore"

    public static var idKeyPath: KeyPath = \Self.id

    public static let attributes: Set<Attribute<EpisodeStore>> = [
        .init(\.id, "id"),
        .init(\.number, "number"),
        .init(\.title, "title"),
        .init(\.thumbnail, "cover"),
        .init(\.progress, "progress"),
        .init(\.lastUpdatedProgress, "lastUpdatedProgress")
    ]
}

// MARK: - ImageSize + ConvertableValue

extension ImageSize: ConvertableValue {
    public static func decode(value primitiveValue: Data) throws -> ImageSize {
        try primitiveValue.toObject()
    }

    public func encode() -> Data {
        (try? toData()) ?? .init()
    }
}
