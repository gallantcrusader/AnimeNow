//
//  DownloaderClient.swift
//
//  Created by ErrorErrorError on 11/24/22.
//
//

import Combine
import ComposableArchitecture
import Foundation
import SharedModels

// MARK: - DownloaderClient

public struct DownloaderClient {
    public let observe: (Anime.ID?) -> AsyncStream<Set<AnimeStorage>>
    public let download: (Request) -> Void
    public let delete: (Anime.ID, Int) async -> Void
    public let count: () -> AsyncStream<Int>
    public let cancel: (Anime.ID, Int) async -> Void
    public let retry: (Anime.ID, Int) async -> Void
    public let reset: () async -> Void
}

public extension DownloaderClient {
    enum Status: Hashable, Codable {
        case pending
        case downloading(progress: Double)
        case downloaded(location: URL)
        case failed

        public var canCancelDownload: Bool {
            switch self {
            case .pending, .downloading:
                return true
            default:
                return false
            }
        }
    }

    struct Request {
        let anime: any AnimeRepresentable
        let episode: any EpisodeRepresentable
        let source: Source

        public init(
            anime: any AnimeRepresentable,
            episode: any EpisodeRepresentable,
            source: Source
        ) {
            self.anime = anime
            self.episode = episode
            self.source = source
        }
    }

    struct AnimeStorage: AnimeRepresentable, Codable {
        public let id: Int
        public var malId: Int? { nil }
        public let title: String
        public let format: Anime.Format
        public let posterImage: [ImageSize]
        public var episodes: Set<EpisodeStorage>
    }

    struct EpisodeStorage: EpisodeRepresentable, Codable {
        public var id: Int { number }
        public let number: Int
        public let title: String
        public let thumbnail: ImageSize?
        public var isFiller: Bool

        public var status: Status

        public var links: Set<EpisodeLink> {
            switch status {
            case let .downloaded(location: url):
                return [.offline(url: url)]
            default:
                return []
            }
        }
    }
}

public extension DownloaderClient.EpisodeStorage {
    var isDownloading: Bool {
        switch status {
        case .downloading:
            return true
        default:
            return false
        }
    }
}

public extension DownloaderClient.AnimeStorage {
    var downloadingCount: Int {
        episodes.filter(\.isDownloading).count
    }

    var downloadingProgress: Double {
        episodes.filter(\.isDownloading).reduce(0.0) { partialResult, episode in
            if case let .downloading(progress) = episode.status {
                return partialResult + progress
            } else {
                return partialResult
            }
        } / max(Double(downloadingCount), 1.0)
    }
}

public extension DownloaderClient.EpisodeStorage {
    var fileExists: Bool {
        if case let .downloaded(location) = status {
            return FileManager.default.fileExists(atPath: location.path)
        }
        return false
    }
}

// MARK: - DownloaderClient + DependencyKey

extension DownloaderClient: DependencyKey {}

public extension DependencyValues {
    var downloaderClient: DownloaderClient {
        get { self[DownloaderClient.self] }
        set { self[DownloaderClient.self] = newValue }
    }
}
