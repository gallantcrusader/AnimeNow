//
//  API.swift
//
//
//  Created by ErrorErrorError on 9/4/22.
//

import Combine
import ComposableArchitecture
import Foundation
import Logger

// MARK: - APIClient

public protocol APIClient {
    @discardableResult
    func request<A: APIBase, O: Decodable>(
        _ api: A,
        _ request: Request<A, O>
    ) async throws -> O
}

// MARK: - APIClientKey

private enum APIClientKey: DependencyKey {
    static var liveValue: any APIClient = APIClientLive()
}

public extension DependencyValues {
    var apiClient: any APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// MARK: - APIBase

public protocol APIBase {
    static var shared: Self { get }
    var base: URL { get }
}

public extension APIBase {
    static var animeNowAPI: AnimeNowAPI { AnimeNowAPI.shared }
    static var aniListAPI: AniListAPI { AniListAPI.shared }
    static var aniSkipAPI: AniSkipAPI { AniSkipAPI.shared }
    static var consumetAPI: ConsumetAPI { ConsumetAPI.shared }
    static var kitsuAPI: KitsuAPI { KitsuAPI.shared }
    static var enimeAPI: EnimeAPI { EnimeAPI.shared }
}

// MARK: - EmptyResponse

public struct EmptyResponse: Decodable {}

public typealias NoResponseRequest<Route: APIBase> = Request<Route, EmptyResponse>

typealias Query = URLQueryItem

extension URLQueryItem {
    init(
        name: String,
        _ value: some CustomStringConvertible
    ) {
        self.init(
            name: name,
            value: value.description
        )
    }
}

// MARK: - Request

public struct Request<Route: APIBase, O: Decodable> {
    var path: [CustomStringConvertible] = []
    var query: [URLQueryItem]?
    var method: Method = .get
    var headers: ((Route) -> [String: CustomStringConvertible])?
    var decoder: JSONDecoder = .init()

    enum Method: CustomStringConvertible {
        case get
        case post(Data)

        var stringValue: String {
            switch self {
            case .get:
                return "GET"
            case .post:
                return "POST"
            }
        }

        var description: String {
            switch self {
            case .get:
                return "GET"
            case let .post(data):
                return "POST: \(String(data: data, encoding: .utf8) ?? "Unknown")"
            }
        }
    }
}
