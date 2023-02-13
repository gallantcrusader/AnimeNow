//
//  DiscordClient.swift
//
//
//  Created by ErrorErrorError on 12/29/22.
//
//

import ComposableArchitecture
import Foundation

// MARK: - DiscordClient

public struct DiscordClient {
    public let isActive: Bool
    public let isConnected: Bool
    public let status: () -> AsyncStream<Status>
    public let setActive: (Bool) async throws -> Void
    public let setActivity: (Activity?) async -> Void
}

public extension DiscordClient {
    enum Status: String, Equatable {
        case connected = "Connected"
        case failed = "Failed"
        case offline = "Offline"
    }

    var isSupported: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
}

// MARK: DiscordClient.Activity

public extension DiscordClient {
    enum Activity {
        case watching(WatchingInfo)
        case searching
        case looking

        public struct WatchingInfo {
            let name: String
            let episode: String
            let image: String
            let progress: Double
            let duration: Double

            public init(
                name: String,
                episode: String,
                image: String,
                progress: Double = 0,
                duration: Double = 0
            ) {
                self.name = name
                self.episode = episode
                self.image = image
                self.progress = progress
                self.duration = duration
            }
        }
    }
}

// MARK: DependencyKey

extension DiscordClient: DependencyKey {
    #if os(iOS)
    public static var liveValue: DiscordClient = .noop
    #endif
}

public extension DependencyValues {
    var discordClient: DiscordClient {
        get { self[DiscordClient.self] }
        set { self[DiscordClient.self] = newValue }
    }
}
