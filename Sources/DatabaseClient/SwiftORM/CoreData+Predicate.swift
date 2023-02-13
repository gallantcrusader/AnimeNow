//  CoreData+Predicate.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/16/22.
//

import Foundation

// MARK: - PredicateProtocol

public protocol PredicateProtocol<Root>: NSPredicate {
    associatedtype Root: ManagedObjectConvertible
}

// MARK: - CompoundPredicate

public final class CompoundPredicate<Root: ManagedObjectConvertible>: NSCompoundPredicate, PredicateProtocol {}

// MARK: - ComparisonPredicate

public final class ComparisonPredicate<Root: ManagedObjectConvertible>: NSComparisonPredicate, PredicateProtocol {}

// MARK: compound operators

public extension PredicateProtocol {
    static func && (
        lhs: Self,
        rhs: Self
    ) -> CompoundPredicate<Self.Root> {
        CompoundPredicate(type: .and, subpredicates: [lhs, rhs])
    }

    static func || (
        lhs: Self,
        rhs: Self
    ) -> CompoundPredicate<Self.Root> {
        CompoundPredicate(type: .or, subpredicates: [lhs, rhs])
    }

    static prefix func ! (not: Self) -> CompoundPredicate<Self.Root> {
        CompoundPredicate(type: .not, subpredicates: [not])
    }
}

// MARK: - comparison operators

public extension ConvertableValue where Self: Equatable {
    static func == <R>(
        kp: some KeyPath<R, Self>,
        value: Self
    ) -> ComparisonPredicate<R> {
        ComparisonPredicate(kp, .equalTo, value)
    }

    static func != <R>(
        kp: some KeyPath<R, Self>,
        value: Self
    ) -> ComparisonPredicate<R> {
        ComparisonPredicate(kp, .notEqualTo, value)
    }
}

public extension ConvertableValue where Self: Comparable {
    static func > <R>(
        kp: some KeyPath<R, Self>,
        value: Self
    ) -> ComparisonPredicate<R> {
        ComparisonPredicate(kp, .greaterThan, value)
    }

    static func < <R>(
        kp: some KeyPath<R, Self>,
        value: Self
    ) -> ComparisonPredicate<R> {
        ComparisonPredicate(kp, .lessThan, value)
    }

    static func <= <R>(
        kp: some KeyPath<R, Self>,
        value: Self
    ) -> ComparisonPredicate<R> {
        ComparisonPredicate(kp, .lessThanOrEqualTo, value)
    }

    static func >= <R>(
        kp: some KeyPath<R, Self>,
        value: Self
    ) -> ComparisonPredicate<R> {
        ComparisonPredicate(kp, .greaterThanOrEqualTo, value)
    }
}

// public extension Sequence where Element: ConvertableValue & Equatable {
//    static func === <R>(
//        kp: some KeyPath<R, Self.Element>,
//        values: Self
//    ) -> ComparisonPredicate<R> {
//        ComparisonPredicate(kp, .in, values)
//    }
// }

// MARK: - internal

internal extension ComparisonPredicate {
    convenience init(
        _ keyPath: KeyPath<Root, some ConvertableValue>,
        _ op: NSComparisonPredicate.Operator,
        _ value: (any ConvertableValue)?
    ) {
        let attribute = Root.attribute(keyPath)
        let ex1 = NSExpression(forKeyPath: attribute.name)
        let ex2 = NSExpression(forConstantValue: value?.encode())
        self.init(leftExpression: ex1, rightExpression: ex2, modifier: .direct, type: op)
    }
}
