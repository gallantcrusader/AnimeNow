//
//  FileClient.swift
//
//
//  Created by ErrorErrorError on 1/16/23.
//
//

import ComposableArchitecture
import Foundation

// MARK: - FileClient

public struct FileClient {
    public var delete: @Sendable (String) async throws -> Void
    public var load: @Sendable (String) async throws -> Data
    public var save: @Sendable (String, Data) async throws -> Void
}

public extension FileClient {
    func load<A: Decodable>(_: A.Type, from fileName: String) async throws -> A {
        try await JSONDecoder().decode(A.self, from: load(fileName))
    }

    func save(_ data: some Encodable, to fileName: String) async throws {
        try await save(fileName, JSONEncoder().encode(data))
    }
}

public extension DependencyValues {
    var fileClient: FileClient {
        get { self[FileClient.self] }
        set { self[FileClient.self] = newValue }
    }
}
