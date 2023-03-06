//
//  CollectionsReducer.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 10/15/22.
//  Copyright © 2022. All rights reserved.
//

import APIClient
import ComposableArchitecture
import DatabaseClient
import Foundation
import OrderedCollections
import SharedModels
import TCACoordinators
import TrackingListClient
import Utilities

// MARK: - CollectionsReducer

public struct CollectionsReducer: ReducerProtocol {
    public enum LocalCollectionName: String {
        case favorites = "Favorites"
    }

    public struct LocalCollections: Equatable {
        // TODO: Change collection store to where anime contains if it has been watched already or wtv
        var favorites = LocalCollection(title: .favorites, animes: [])
        var collections = [CollectionStore]()
    }

    public struct NetworkCollections: Equatable {}

    public enum Route: Equatable, CaseIterable {
        case local
        case anilist
        case myanimelist
        case kitsu

        var text: String {
            switch self {
            case .local:
                return "Local"
            case .anilist:
                return "AniList"
            case .myanimelist:
                return "MyAnimeList"
            case .kitsu:
                return "Kitsu"
            }
        }
    }

    public struct State: Equatable {
        @BindingState
        var route: Route
        var local = LocalCollections()
        var anilist = AuthState<AniListClient.Collections>.unauthenticated
        var myanimelist = AuthState<MyAnimeListClient.Collections>.unauthenticated
        var kitsu = AuthState<KitsuClient.Collections>.unauthenticated

        var hasInitialized = false

        public init(
            route _: Route = .local,
            favorites _: [AnimeStore] = [],
            collections _: [CollectionStore] = []
        ) {
            self.route = .local
        }
    }

    public enum Action: BindableAction, Equatable {
        case onAppear
        case onAddNewCollectionTapped
        case onAnimeTapped(Anime.ID)
        case removeCollection(CollectionStore.ID)
        case remove(AnimeStore.ID, CollectionStore.ID)
        case removeFromFavories(AnimeStore.ID)
        case updateItems(in: WritableKeyPath<State, [AnimeStore]>, update: [AnimeStore])
        case updateCollections(in: WritableKeyPath<State, [CollectionStore]>, update: [CollectionStore])
        case anilist(AuthState<AniListClient.Collections>)
        case myanimelist(AuthState<MyAnimeListClient.Collections>)
        case kitsu(AuthState<KitsuClient.Collections>)
        case binding(BindingAction<State>)
    }

    @Dependency(\.apiClient)
    var apiClient

    @Dependency(\.databaseClient)
    var databaseClient

    @Dependency(\.anilistClient)
    var anilistClient

    @Dependency(\.myanimelistClient)
    var myanimelistClient

    @Dependency(\.kitsuClient)
    var kitsuClient

    @Dependency(\.trackingListClient)
    var trackingListClient

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        Reduce(self.core)
    }
}

extension CollectionsReducer {
    struct InitializationId: Hashable {}

    // swiftlint:disable cyclomatic_complexity
    func core(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .onAppear:
            return .run { send in
                await withTaskCancellation(id: InitializationId.self, cancelInFlight: true) {
                    await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            let observing = databaseClient.observe(
                                AnimeStore.all.where(\.isFavorite == true)
                            )

                            for await items in observing {
                                await send(
                                    .updateItems(in: \.local.favorites.animes, update: items)
                                )
                            }
                        }

                        group.addTask {
                            let observing = databaseClient.observe(CollectionStore.all)

                            for await collections in observing {
                                await send(
                                    .updateCollections(
                                        in: \.local.collections,
                                        update: collections
                                    )
                                )
                            }
                        }

                        group.addTask {
                            if await anilistClient.loggedIn() {
                                await send(.anilist(.authenticating))

                                do {
                                    let collections = try await anilistClient.userCollections()
                                    await send(.anilist(.authenticated(collections)))
                                } catch {
                                    await send(.anilist(.failed))
                                }
                            } else {
                                await send(.anilist(.unauthenticated))
                            }
                        }

                        group.addTask {
                            if await myanimelistClient.loggedIn() {
                                await send(.myanimelist(.authenticating))
                                do {
                                    let collections = try await myanimelistClient.userCollections()
                                    await send(.myanimelist(.authenticated(collections)))
                                } catch {
                                    await send(.myanimelist(.failed))
                                }
                            } else {
                                await send(.myanimelist(.unauthenticated))
                            }
                        }

                        group.addTask {
                            if await kitsuClient.loggedIn() {
                                await send(.kitsu(.authenticating))
                                do {
                                    let collections = try await kitsuClient.userCollections()
                                    await send(.kitsu(.authenticated(collections)))
                                } catch {
                                    await send(.kitsu(.failed))
                                }
                            } else {
                                await send(.kitsu(.unauthenticated))
                            }
                        }
                    }
                }
            }

        case let .updateItems(keyPath, items):
            state[keyPath: keyPath] = items

        case let .updateCollections(keyPath, collections):
            state[keyPath: keyPath] = collections

        case let .removeCollection(collectionId):
            guard let collection = state.local.collections[id: collectionId] else {
                break
            }
            return .run {
                try await databaseClient.delete(collection)
            }

        case let .removeFromFavories(animeId):
            return .run {
                try await databaseClient.update(animeId, \AnimeStore.isFavorite, false)
            }

        case let .remove(animeId, collectionId):
            guard var collection = state.local.collections[id: collectionId] else {
                break
            }
            collection.animes.removeAll { $0.id == animeId }

            return .run { [collection] in
                try await databaseClient.insert(collection)
            }

        case .onAddNewCollectionTapped:
            break

        case .onAnimeTapped:
            break

        case let .anilist(auth):
            state.anilist = auth

        case let .myanimelist(auth):
            state.myanimelist = auth

        case let .kitsu(auth):
            state.kitsu = auth

        case .binding:
            break
        }
        return .none
    }
}

// MARK: - CollectionState

// swiftlint:disable type_name
public protocol CollectionState: Identifiable {
    associatedtype A: AnimeRepresentable
    associatedtype C: RandomAccessCollection<A>
    var id: ID { get }
    var name: String { get }
    var animes: C { get }
}

// MARK: - LocalCollection

public struct LocalCollection: CollectionState, Equatable {
    public typealias A = AnimeStore
    public typealias C = [AnimeStore]

    public var id: Int { title.hashValue }
    public var title: CollectionsReducer.LocalCollectionName
    public var name: String { title.rawValue }
    public var animes: [AnimeStore]
}

// MARK: - CollectionStore + CollectionState

// swiftlint:disable type_name
extension CollectionStore: CollectionState {
    public typealias A = AnimeStore
    public typealias C = OrderedSet<A>

    public var name: String { title.value }
}

// MARK: - AniListModels.MediaListGroup + CollectionState

extension AniListModels.MediaListGroup: CollectionState {
    public typealias A = Anime
    public typealias C = [A]

    public var id: String { name }
    public var animes: [A] { entries.compactMap(\.anime) }
}

extension AniListModels.MediaList {
    var anime: Anime? {
        media.flatMap(AniListModels.convert(from:))
    }
}

// MARK: - MyAnimeListClient.ListGroup + CollectionState

extension MyAnimeListClient.ListGroup: CollectionState {
    public typealias A = MalModels.Media
    public typealias C = [A]

    public var id: MalModels.Status {
        status
    }

    public var name: String {
        id.rawValue.capitalized
    }

    public var animes: [A] {
        items.map(\.node)
    }
}

// MARK: - MalModels.Media + AnimeRepresentable, Hashable

extension MalModels.Media: AnimeRepresentable, Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }

    public var malId: Int? {
        id
    }

    public var format: SharedModels.Anime.Format {
        switch media_type {
        case .none, .some(.tv), .some(.unknown):
            return .tv
        case .some(.movie):
            return .movie
        case .some(.music):
            return .special
        case .some(.special):
            return .special
        case .some(.ona):
            return .ona
        case .some(.ova):
            return .ova
        }
    }

    public var posterImage: [SharedModels.ImageSize] {
        [
            main_picture
                .map(\.medium)
                .flatMap { URL(string: $0) }
                .flatMap { .medium($0) },
            main_picture
                .flatMap(\.large)
                .flatMap { URL(string: $0) }
                .flatMap { .large($0) }
        ]
        .compactMap { $0 }
    }
}

extension KitsuClient.Collections {
    public struct CollectionGroup: Equatable, CollectionState {
        public typealias A = Anime
        public typealias C = [A]

        public var id: String { name }
        public let name: String
        let library: KitsuModels.LibraryEntryConnection

        public var animes: [A] {
            library.nodes.map(\.media).compactMap(KitsuModels.convert(from:))
        }
    }

    var collections: [CollectionGroup] {
        [
            .init(name: "Planned", library: planned),
            .init(name: "Current", library: current),
            .init(name: "Completed", library: completed),
            .init(name: "Dropped", library: dropped),
            .init(name: "On Hold", library: onHold)
        ]
    }
}
