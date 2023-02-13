//
//  Live.swift
//
//
//  Created by ErrorErrorError on 1/16/23.
//
//

import ComposableArchitecture
import Foundation

// MARK: - FileClient + DependencyKey

extension FileClient: DependencyKey {
    public static let liveValue = {
        let mainDirectory = Self.applicationDirectory

        if !FileManager.default.fileExists(atPath: mainDirectory.path) {
            try? FileManager.default.createDirectory(
                at: mainDirectory,
                withIntermediateDirectories: true
            )
        }

        return Self(
            delete: { url in
                try FileManager.default.removeItem(
                    at: mainDirectory
                        .appendingPathComponent(url)
                        .appendingPathExtension("json")
                )
            },
            load: { url in
                try Data(
                    contentsOf: mainDirectory
                        .appendingPathComponent(url)
                        .appendingPathExtension("json")
                )
            },
            save: { url, data in
                try data.write(
                    to: mainDirectory
                        .appendingPathComponent(url)
                        .appendingPathExtension("json")
                )
            }
        )
    }()
}

public extension FileClient {
    static let applicationDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "com.errorerrorerror.animenow",
            isDirectory: true
        )
}
