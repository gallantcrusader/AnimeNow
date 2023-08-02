//
//  ConsumetAPI.swift
//  Anime Now! (iOS)
//
//  Created by ErrorErrorError on 9/29/22.
//

import Foundation
import SharedModels
import Utilities

// MARK: - ConsumetEndpoint

public struct ConsumetEndpoint<D: Decodable>: Endpoint {
    var base: URL
    var path: [CustomStringConvertible]
    var query: [Query]
    var method: Request<D>.Method
    var headers: [String: CustomStringConvertible]?

    init(
        base: URL?,
        path: [CustomStringConvertible] = [],
        query: [Query] = [],
        method: Request<D>.Method? = .get,
        headers: [String: CustomStringConvertible]? = nil
    ) {
        self.base = base ?? URL(string: "https://api.consumet.org").unsafelyUnwrapped
        self.path = path
        self.query = query
        self.method = method ?? .get
        self.headers = headers
    }
}

// MARK: - Consumet + Request

public extension Request {
    static func consumet<D: Decodable>(_ endpoint: ConsumetEndpoint<D>) -> Request<D> {
        endpoint.build()
    }
}

public extension ConsumetEndpoint {
    static func anilistEpisodes(
        hostname: URL?,
        animeId: Int,
        dub: Bool,
        provider: String,
        fetchFiller: Bool = true
    ) -> ConsumetEndpoint<[ConsumetModels.Episode]> {
        .init(
            base: hostname,
            path: ["meta", "anilist", "episodes", animeId],
            query: [
                .init(name: "dub", dub),
                .init(name: "provider", provider.lowercased()),
                .init(name: "fetchFiller", fetchFiller)
            ]
        )
    }

    static func anilistWatch(
        hostname: URL?,
        episodeId: String,
        dub: Bool,
        provider: String
    ) -> ConsumetEndpoint<ConsumetModels.StreamingLinksPayload> {
        .init(
            base: hostname,
            path: ["meta", "anilist", "watch", episodeId],
            query: [
                .init(name: "dub", dub),
                .init(name: "provider", provider)
            ]
        )
    }

    static func listProviders(
        hostname: URL?,
        of type: ConsumetModels.ProviderType = .ANIME
    ) -> ConsumetEndpoint<[ProviderInfo]> {
        .init(
            base: hostname,
            path: ["utils", "providers"],
            query: [
                .init(name: "type", type.rawValue)
            ]
        )
    }
}

// MARK: - ConsumetModels

public enum ConsumetModels {}

public extension ConsumetModels {
    enum ProviderType: String {
        case ANIME
        case MANGA
    }

    struct Anime: Equatable, Decodable {
        let id: String
        let subOrDub: AudioType
        let episodes: [Episode]

        enum AudioType: String, Equatable, Decodable {
            case sub
            case dub
        }
    }

    struct Episode: Equatable, Decodable {
        public let id: String
        public let number: Int
        public let title: String?
        public let type: String?
        public let image: String?
        public let description: String?
        @Defaultable<False>
        public var isFiller: Bool
    }

    struct StreamingLinksPayload: Decodable {
        let sources: [StreamingLink]
        let subtitles: [Subtitle]?
        let intro: Intro?
        let headers: [String: String]?
    }

    struct StreamingLink: Decodable {
        let url: String
        @Defaultable<True>
        var isM3U8: Bool
        @Defaultable<False>
        var isDASH: Bool
        let quality: String?
    }

    struct Subtitle: Decodable {
        let url: String
        let lang: String
    }

    struct Intro: Decodable {
        let start: Int
        let end: Int
    }
}

private extension Source.Quality {
    init?(_ quality: String) {
        if let matched = Self.allCases.first(where: { $0.description.localizedCaseInsensitiveContains(quality) }) {
            self = matched
            return
        }

        if quality.localizedCaseInsensitiveContains("default") {
            self = .auto
            return
        } else if quality.localizedCaseInsensitiveContains("backup") {
            self = .autoalt
            return
        }
        return nil
    }
}

// MARK: - Converters

public extension ConsumetModels {
    static func convert(from payload: StreamingLinksPayload) -> SharedModels.SourcesOptions {
        var sources: [SharedModels.Source] = []

        payload.sources.forEach { link in
            guard let quality = Source.Quality(link.quality ?? "default") else {
                return
            }

            guard let url = URL(string: link.url) else {
                return
            }

            if let source = sources.first(where: { $0.url.absoluteString == link.url }) {
                if source.quality <= quality {
                    sources.removeAll { $0.url.absoluteString == link.url }
                } else {
                    return
                }
            }

            var format = Source.Format.m3u8

            if link.isDASH {
                format = .mpd
            }

            sources.append(
                .init(
                    url: url,
                    quality: quality,
                    format: format,
                    headers: payload.headers
                )
            )
        }

        let subtitles: [SharedModels.SourcesOptions.Subtitle] = (payload.subtitles ?? [])
            .compactMap { subtitle in
                guard let url = URL(string: subtitle.url),
                      subtitle.lang != "Thumbnails"
                else {
                    return nil
                }
                return SharedModels.SourcesOptions.Subtitle(
                    url: url,
                    lang: subtitle.lang
                )
            }

        return .init(sources.sorted(by: \.quality), subtitles: subtitles)
    }

    static func convert(from episodes: [ConsumetModels.Episode]) -> [SharedModels.Episode] {
        episodes.compactMap(convert(from:))
    }

    static func convert(from episode: ConsumetModels.Episode) -> SharedModels.Episode {
        let thumbnail: ImageSize?

        if let thumbnailString = episode.image, let thumbnailURL = URL(string: thumbnailString) {
            thumbnail = .original(thumbnailURL)
        } else {
            thumbnail = nil
        }

        let title = (episode.title?.isEmpty ?? true) ? "Episode \(episode.number)" : episode
            .title ?? "Episode \(episode.number)"

        return SharedModels.Episode(
            title: title,
            number: episode.number,
            description: episode.description ?? "Description is not available for this episode.",
            thumbnail: thumbnail,
            isFiller: episode.isFiller
        )
    }
}
