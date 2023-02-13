//  CoreData+Request.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/16/22.
//
//  Modified version of https://github.com/prisma-ai/Sworm

import CoreData
import Foundation

// MARK: - Request

public struct Request<PlainObject: ManagedObjectConvertible> {
    var fetchLimit: Int?
    var predicate: NSPredicate?
    var sortDescriptors: [SortDescriptor] = []

    fileprivate init() {}
}

public extension Request {
    func `where`(
        _ predicate: some PredicateProtocol<PlainObject>
    ) -> Self {
        var obj = self
        obj.predicate = predicate
        return obj
    }

    func sort(
        _ keyPath: KeyPath<PlainObject, some Comparable>,
        ascending: Bool = true
    ) -> Self {
        var obj = self
        obj.sortDescriptors.append(
            .init(
                keyPath: keyPath,
                ascending: ascending
            )
        )
        return obj
    }

    func limit(_ count: Int) -> Self {
        var obj = self
        obj.fetchLimit = max(0, count)
        return obj
    }
}

extension Request {
    func makeFetchRequest<ResultType: NSFetchRequestResult>(
        ofType resultType: NSFetchRequestResultType = .managedObjectResultType,
        attributesToFetch: Set<Attribute<PlainObject>> = PlainObject.attributes
    ) -> NSFetchRequest<ResultType> {
        let properties = attributesToFetch.filter { !$0.isRelation }.map(\.name)

        let fetchRequest = NSFetchRequest<ResultType>(entityName: PlainObject.entityName)
        fetchRequest.resultType = resultType
        fetchRequest.propertiesToFetch = properties
        fetchRequest.includesPropertyValues = !properties.isEmpty

        fetchLimit.flatMap { limit in
            fetchRequest.fetchLimit = limit
        }

        if let predicate {
            fetchRequest.predicate = predicate
        }

        if !sortDescriptors.isEmpty {
            fetchRequest.sortDescriptors = sortDescriptors.map(\.object)
        }

        return fetchRequest
    }
}

public extension ManagedObjectConvertible {
    static var all: Request<Self> {
        .init()
    }
}
