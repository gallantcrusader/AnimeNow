//
//  AniListClient.swift
//
//
//  Created by ErrorErrorError on 2/25/23.
//
//

import APIClient
import AuthenticationClient
import ComposableArchitecture
import FileClient
import Foundation
import Utilities

// MARK: - AniListClient

public struct AniListClient {
    public let initialize: @Sendable () async throws -> Void
    public let logIn: @Sendable () async throws -> User
    public let logOut: @Sendable ()
        async -> Void
    public let loggedIn: @Sendable ()
        async -> Bool
    public let refreshUser: @Sendable () async throws -> User
    public let user: @Sendable ()
        async -> User?
    public let userCollections: @Sendable () async throws -> Collections
}

public extension AniListClient {
    typealias User = AniListModels.User
    typealias Collections = AniListModels.MediaListCollection

    fileprivate struct AccessToken: Equatable, Codable {
        let token: String
        let expires: Date
    }
}

// MARK: DependencyKey

extension AniListClient: DependencyKey {
    public static let liveValue: Self = {
        actor Session {
            nonisolated let accessToken = LockIsolated<AccessToken?>(nil)
            var currentUser: User?
            var userCollections: Collections?

            private static let accessTokenFile = "anilist-access-token"

            @Dependency(\.fileClient)
            private var fileClient

            @Dependency(\.authenticationClient)
            private var authenticationClient

            @Dependency(\.apiClient)
            private var apiClient

            init() {}

            func initialize() async throws {
                let accessToken = try await fileClient.load(AccessToken.self, from: Self.accessTokenFile)
                self.accessToken.setValue(accessToken)
                _ = try await refreshUser()
            }

            func logIn() async throws -> User {
                var components = URLComponents()
                components.scheme = "https"
                components.host = "anilist.co"
                components.path = "/api/v2/oauth/authorize"
                components.queryItems = .init([
                    "client_id": 11_352,
                    "response_type": "token"
                ])

                let loginURL = components.url.unsafelyUnwrapped

                let url = try await authenticationClient.authenticate(loginURL)

                var urlComponents = URLComponents()
                urlComponents.query = url.fragment

                guard let token = urlComponents.queryItems?.first(where: { $0.name == "access_token" })?.value,
                      let expirationString = urlComponents.queryItems?.first(where: { $0.name == "expires_in" })?.value,
                      let expiration = Double(expirationString)
                else {
                    throw URLError(.badServerResponse)
                }

                let time = Date().advanced(by: expiration)

                let accessToken = AccessToken(token: token, expires: time)
                try await updateAccessToken(accessToken)

                return try await refreshUser()
            }

            func logOut() async {
                currentUser = nil
                userCollections = nil
                try? await updateAccessToken(nil)
            }

            func refreshUser() async throws -> User {
                let user = try await tokenRequired { [unowned self] accessToken in
                    try await apiClient.request(
                        .anilist(
                            .graphql(AniListModels.Viewer.self, accessToken.token)
                        )
                    )
                    .data
                    .Viewer
                }
                currentUser = user
                return user
            }

            func userCollections(refresh: Bool = false) async throws -> AniListModels.MediaListCollection {
                if !refresh, let userCollections {
                    return userCollections
                } else {
                    let collections = try await userRequired { [unowned self] user in
                        try await apiClient.request(
                            .anilist(
                                .graphql(
                                    AniListModels.MediaListCollectionQuery.self,
                                    .init(userId: user.id)
                                )
                            )
                        )
                        .data
                        .MediaListCollection
                    }
                    userCollections = collections
                    return collections
                }
            }

            private func userRequired<O>(_ operation: @escaping (User) async throws -> O) async throws -> O {
                if let currentUser {
                    return try await operation(currentUser)
                } else {
                    return try await operation(try await refreshUser())
                }
            }

            private func tokenRequired<O>(
                _ operation: @escaping (AccessToken) async throws -> O
            ) async throws -> O {
                guard let token = accessToken.value else {
                    throw URLError(.userAuthenticationRequired)
                }

                return try await operation(token)
            }

            private func updateAccessToken(_ accessToken: AccessToken?) async throws {
                if let accessToken {
                    try await fileClient.save(accessToken, to: Self.accessTokenFile)
                } else {
                    try await fileClient.delete(Self.accessTokenFile)
                }
                self.accessToken.setValue(accessToken)
            }
        }

        let session = Session()

        return Self(
            initialize: { try await session.initialize() },
            logIn: { try await session.logIn() },
            logOut: { await session.logOut() },
            loggedIn: { session.accessToken.value != nil },
            refreshUser: { try await session.refreshUser() },
            user: { await session.currentUser },
            userCollections: { try await session.userCollections() }
        )
    }()
}

public extension DependencyValues {
    var anilistClient: AniListClient {
        get { self[AniListClient.self] }
        set { self[AniListClient.self] = newValue }
    }
}
