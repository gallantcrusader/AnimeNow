//  CollectionStoreModel4ToModel5
//  Anime Now! (iOS)
//
//  Created by ErrorErrorError on 11/9/22.
//
//

import CoreData
import Foundation
import SharedModels

class CollectionStoreModel4ToModel5: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in _: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        if sInstance.entity.name == "CDCollectionStore" {
            let lastUpdated = sInstance.primitiveValue(forKey: "lastUpdated") as? Date ?? .init()
            let userRemovable = sInstance.primitiveValue(forKey: "userRemovable") as? Bool ?? false

            if let title = sInstance.primitiveValue(forKey: "title") as? String {
                let newCollection = NSEntityDescription.insertNewObject(
                    forEntityName: "CDCollectionStore",
                    into: manager.destinationContext
                )

                newCollection.setValue(lastUpdated, forKey: "lastUpdated")

                if !userRemovable {
                    if title == "Watchlist" {
                        try newCollection.setValue(
                            CollectionStore.Title.planning.toData(), forKey: "title"
                        )
                    } else {
                        try newCollection.setValue(CollectionStore.Title.custom(title).toData(), forKey: "title")
                    }
                } else {
                    try newCollection.setValue(CollectionStore.Title.custom(title).toData(), forKey: "title")
                }
            }
        }
    }
}
