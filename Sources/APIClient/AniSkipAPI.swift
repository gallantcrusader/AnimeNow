//
//  AniSkipAPI.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 10/11/22.
//

import Foundation
import SharedModels
import Utilities

// MARK: - AniSkipEndpoint

public struct AniSkipEndpoint<D: Decodable>: Endpoint {
    var base = URL(string: "https://api.aniskip.com/v2").unsafelyUnwrapped
    var path: [CustomStringConvertible] = []
    var query: [Query] = []
    var method: Request<D>.Method = .get
    var headers: [String: CustomStringConvertible]?
}

public extension AniSkipEndpoint {
    static func skipTime(
        malId: Int,
        episode: Int,
        types: [AniSkipModels.SkipItem.SkipType] = .allCases,
        episodeLength: Int = 0
    ) throws -> AniSkipEndpoint<AniSkipModels.Response> {
        .init(
            path: ["skip-times", "\(malId)", "\(episode)"],
            query: types.map { .init(name: "types", $0.rawValue) } + [
                .init(name: "episodeLength", episodeLength)
            ]
        )
    }
}

// MARK: - AniSkip + Request

public extension Request {
    static func aniskip<D: Decodable>(_ endpoint: AniSkipEndpoint<D>) -> Request<D> {
        endpoint.build()
    }
}

// MARK: - AniSkipModels

public enum AniSkipModels {}

public extension AniSkipModels {
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

public extension AniSkipModels {
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
