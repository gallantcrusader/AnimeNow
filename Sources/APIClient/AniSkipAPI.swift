//
//  AniSkipAPI.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 10/11/22.
//

import Foundation
import SharedModels
import Utilities

// MARK: - AniSkipAPI

public final class AniSkipAPI: APIBase {
    public static var shared: AniSkipAPI = .init()

    // swiftlint:disable force_unwrapping
    public let base = URL(string: "https://api.aniskip.com/v2")!

    private init() {}
}

public extension Request where Route == AniSkipAPI {
    static func skipTime(
        malId: Int,
        episode: Int,
        types: [AniSkipAPI.SkipItem.SkipType] = .allCases,
        episodeLength: Int = 0
    ) -> Request<Route, AniSkipAPI.Response> {
        .init(
            path: ["skip-times", "\(malId)", "\(episode)"],
            query: types.map { .init(name: "types", $0.rawValue) } + [
                .init(name: "episodeLength", episodeLength)
            ]
        )
    }
}

public extension AniSkipAPI {
    struct Response: Decodable {
        public let found: Bool
        public let results: [SkipItem]
        public let statusCode: Int
    }

    struct SkipItem: Decodable {
        let interval: Interval
        let episodeLength: Double
        let skipType: SkipType

        public enum SkipType: String, Decodable, CaseIterable {
            case ed
            case op
            case mixedEd = "mixed-ed"
            case mixedOp = "mixed-op"
            case recap
        }

        public struct Interval: Decodable {
            let startTime: Double
            let endTime: Double
        }
    }
}

public extension AniSkipAPI {
    static func convert(from items: [SkipItem]) -> [SharedModels.SkipTime] {
        items.map { item -> SharedModels.SkipTime in
            let option: SharedModels.SkipTime.Option

            switch item.skipType {
            case .ed:
                option = .ending
            case .op:
                option = .opening
            case .mixedEd:
                option = .mixedEnding
            case .mixedOp:
                option = .mixedOpening
            case .recap:
                option = .recap
            }

            return .init(
                startTime: item.interval.startTime / item.episodeLength,
                endTime: item.interval.endTime / item.episodeLength,
                type: option
            )
        }
    }
}
