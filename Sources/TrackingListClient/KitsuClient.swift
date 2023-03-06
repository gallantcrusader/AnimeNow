//
//  KitsuClient.swift
//
//
//  Created by ErrorErrorError on 3/1/23.
//
//

import APIClient
import AuthenticationClient
import ComposableArchitecture
import FileClient
import Foundation
import Utilities

// MARK: - KitsuClient

public struct KitsuClient {
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

public extension KitsuClient {
    typealias User = KitsuModels.Profile
    typealias Collections = KitsuModels.Library
    fileprivate typealias AccessToken = KitsuModels.Token
}

public extension DependencyValues {
    var kitsuClient: KitsuClient {
        get { self[KitsuClient.self] }
        set { self[KitsuClient.self] = newValue }
    }
}

extension KitsuClient.AccessToken {
    var isValid: Bool {
        created_at.advanced(by: .init(expires_in)) > .init()
    }
}

// MARK: - KitsuClient + DependencyKey

extension KitsuClient: DependencyKey {
    private actor Session {
        nonisolated let accessToken = LockIsolated<AccessToken?>(nil)
        nonisolated let user = LockIsolated<User?>(nil)
        var userCollections: Collections?

        private static let accessTokenFile = "kitsu-access-token"

        @Dependency(\.apiClient)
        private var apiClient

        @Dependency(\.authenticationClient)
        private var authenticationClient

        @Dependency(\.fileClient)
        private var fileClient

        func initialize() async throws {
            let accessToken = try await fileClient.load(AccessToken.self, from: Self.accessTokenFile)
            self.accessToken.setValue(accessToken)
            _ = try await refreshUser()
        }

        func logIn() async throws -> User {
            enum KitsuLogInError: Error {
                case malformedPassword
            }

            let token = try await authenticationClient.logIn(
                title: "Kitsu",
                image: "kitsu_logo",
                description: "Log in with your Kitsu credentials!"
            ) { [unowned self] userInfo in
                guard let password = userInfo.password
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    throw KitsuLogInError.malformedPassword
                }
                return try await apiClient.request(
                    .kitsu(
                        .createToken(
                            userInfo.username,
                            password
                        )
                    )
                )
            }

            try await updateAccessToken(token)
            return try await refreshUser()
        }

        func logOut() async {
            user.setValue(nil)
            userCollections = nil
            try? await updateAccessToken(nil)
        }

        func refreshUser() async throws -> User {
            try await tokenRequired { [unowned self] token in
                let user = try await apiClient.request(
                    .kitsu(
                        .graphql(KitsuModels.CurrentAccountQuery.self, .init(), token.access_token)
                    )
                )
                .data
                .currentAccount
                .profile
                self.user.setValue(user)
                return user
            }
        }

        func userCollections(refresh: Bool = false) async throws -> Collections {
            if !refresh, let userCollections {
                return userCollections
            } else {
                let library = try await tokenRequired { [unowned self] token in
                    try await apiClient.request(
                        .kitsu(
                            .graphql(
                                KitsuModels.CurrentAccountQuery.self,
                                .init(
                                    arguments: .init(
                                        profileArguments: .init(
                                            libraryArguments: .init()
                                        )
                                    )
                                ),
                                token.access_token
                            )
                        )
                    )
                }
                .data
                .currentAccount
                .profile
                .library

                guard let library else {
                    throw URLError(.resourceUnavailable)
                }
                userCollections = library
                return library
            }
        }

        private func tokenRequired<O>(_ operation: @escaping (AccessToken) async throws -> O) async throws -> O {
            guard let token = accessToken.value else {
                throw URLError(.userAuthenticationRequired)
            }

            if token.isValid {
                return try await operation(token)
            } else {
                let newToken = try await apiClient.request(
                    .kitsu(.refreshToken(token.refresh_token))
                )
                try await updateAccessToken(newToken)
                return try await operation(newToken)
            }
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

    public static let liveValue: KitsuClient = {
        let session = Session()

        return .init(
            initialize: { try await session.initialize() },
            logIn: { try await session.logIn() },
            logOut: { await session.logOut() },
            loggedIn: { session.accessToken.value != nil },
            refreshUser: { try await session.refreshUser() },
            user: { session.user.value },
            userCollections: { try await session.userCollections() }
        )
    }()
}
