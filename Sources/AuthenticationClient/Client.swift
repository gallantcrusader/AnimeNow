//
//  Client.swift
//
//
//  Created by ErrorErrorError on 2/17/23.
//
//

import ComposableArchitecture
import Foundation

// MARK: - AuthenticationClient

public protocol AuthenticationClient {
    @MainActor
    func authenticate(_ url: URL) async throws -> URL

    @MainActor
    func logIn<O>(
        title: String,
        image: String,
        description: String,
        validate: @escaping @Sendable (AuthenticationClientModels.LoginInfo) async throws -> O
    ) async throws -> O
}

// MARK: - AuthenticationClientModels

public struct AuthenticationClientModels {}

// MARK: AuthenticationClientModels.LoginInfo

public extension AuthenticationClientModels {
    struct LoginInfo {
        public let username: String
        public let password: String
    }
}

// MARK: - AuthenticationClientKey

struct AuthenticationClientKey: DependencyKey {
    static let liveValue: AuthenticationClient = AuthenticationClientLive()
}

public extension DependencyValues {
    var authenticationClient: any AuthenticationClient {
        get { self[AuthenticationClientKey.self] }
        set { self[AuthenticationClientKey.self] = newValue }
    }
}
