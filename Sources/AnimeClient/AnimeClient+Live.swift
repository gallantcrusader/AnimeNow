//
//  AnimeClient+Live.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 9/12/22.
//

import APIClient
import Combine
import ComposableArchitecture
import Foundation
import SharedModels
import SociableWeaver
import Utilities

public extension AnimeClient {
    static let liveValue: AnimeClient = {
        @Dependency(\.apiClient)
        var apiClient

        let cachedStreamingProviders = Cache<String, AnimeStreamingProvider>()

        return Self {
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [.sort([.TRENDING_DESC, .POPULARITY_DESC])]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getTopUpcomingAnime: {
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [
                                    .sort([.TRENDING_DESC, .POPULARITY_DESC]),
                                    .status(.NOT_YET_RELEASED)
                                ]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getTopAiringAnime: {
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [.sort([.TRENDING_DESC, .SCORE_DESC]), .status(.RELEASING)]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getHighestRatedAnime: {
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [.sort([.SCORE_DESC]), .status(.RELEASING)]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getMostPopularAnime: {
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [.sort([.POPULARITY_DESC])]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getAnimes: { animeIds in
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [.idIn(animeIds)]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getAnime: { animeId in
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.Media.self,
                        .init(filters: [.id(animeId)])
                    )
                )
            )
            return AniListModels.convert(from: response.data.Media)
        } searchAnimes: { query in
            let response = try await apiClient.request(
                .anilist(
                    .graphql(
                        AniListModels.MediaPageQuery.self,
                        .init(
                            itemArguments: .init(
                                filters: .defaultArgs + [.search(query), .sort([.POPULARITY_DESC])]
                            )
                        )
                    )
                )
            )
            return response.data.Page.items
                .map(AniListModels.convert(from:))
        } getRecentlyUpdated: {
            let updated = try await apiClient.request(.enime(.recentEpisodes()))
            return updated.data.map(EnimeModels.convert)
        } getEpisodes: { animeId, provider in
            if let episodesCached = cachedStreamingProviders.value(forKey: "\(animeId)-\(provider.name)") {
                return episodesCached
            }

            async let sub = try? await apiClient.request(
                .consumet(
                    .anilistEpisodes(
                        animeId: animeId,
                        dub: false,
                        provider: provider.name
                    )
                )
            )

            async let dub = try? await apiClient.request(
                .consumet(
                    .anilistEpisodes(
                        animeId: animeId,
                        dub: true,
                        provider: provider.name
                    )
                )
            )

            var providerData = AnimeStreamingProvider(
                name: provider.name,
                logo: provider.logo,
                episodes: mergeSources(
                    await sub ?? .init(),
                    await dub ?? .init()
                )
            )

            cachedStreamingProviders.update(providerData, forKey: "\(animeId)-\(provider.name)")

            return providerData
        } getSources: { provider, link in
            switch link {
            case let .stream(id, audio):
                let response = try await apiClient.request(
                    .consumet(
                        .anilistWatch(
                            episodeId: id,
                            dub: audio.isDub,
                            provider: provider
                        )
                    )
                )

                return ConsumetModels.convert(from: response)
            case let .offline(url):
                return .init([
                    .init(
                        url: url,
                        quality: .auto
                    )
                ])
            }
        } getSkipTimes: { malId, episodeNumber in
            let response = try await apiClient.request(
                .aniskip(
                    .skipTime(
                        malId: malId,
                        episode: episodeNumber
                    )
                )
            )
            return AniSkipModels.convert(from: response.results)
        } getAnimeProviders: {
            try await apiClient.request(
                .consumet(
                    .listProviders(of: .ANIME)
                )
            )
        }
    }()
}

private extension AnimeClient {
    static func mergeSources(
        _ sub: [ConsumetModels.Episode],
        _ dub: [ConsumetModels.Episode]
    ) -> [Episode] {
        var episodes = [Episode]()

        let primary = sub.sorted(by: \.number)
        let secondary = dub.sorted(by: \.number)

        let maxEpisodesCount = max(
            primary.last?.number ?? primary.count,
            secondary.last?.number ?? secondary.count
        )

        for mainInx in 0..<maxEpisodesCount {
            let episodeNumber = mainInx + 1
            var providers = Set<EpisodeLink>()

            var mainEpisodeInfo: ConsumetModels.Episode?

            primary.filter { $0.number == episodeNumber }
                .forEach { episode in
                    if mainEpisodeInfo == nil {
                        mainEpisodeInfo = episode
                    }
                    providers.insert(.stream(id: episode.id, audio: .sub))
                }

            secondary.filter { $0.number == episodeNumber }
                .forEach { episode in
                    if mainEpisodeInfo == nil {
                        mainEpisodeInfo = episode
                    }
                    if let type = episode.type {
                        providers.insert(.stream(id: episode.id, audio: .custom(type)))
                    } else {
                        providers.insert(.stream(id: episode.id, audio: .dub))
                    }
                }

            guard let mainEpisodeInfo else {
                continue
            }

            var episode = ConsumetModels.convert(from: mainEpisodeInfo)
            episode.links = providers
            episodes.append(episode)
        }

        return episodes
    }
}
