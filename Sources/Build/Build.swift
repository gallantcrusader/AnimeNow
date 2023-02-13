//
//  DeviceInfoClient.swift
//
//
//  Created by ErrorErrorError on 1/26/23.
//
//

import ComposableArchitecture
import Foundation

// MARK: - Build

public struct Build {
    public var version: () -> String
    public var gitSha: () -> String
}

public extension DependencyValues {
    var build: Build {
        get { self[Build.self] }
        set { self[Build.self] = newValue }
    }
}

// MARK: - Build + DependencyKey

extension Build: DependencyKey {
    public static let liveValue: Build = Self(
        version: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown" },
        gitSha: { Bundle.main.infoDictionary?["GitSha"] as? String ?? "Unknown" }
    )

    public static let previewValue = noop
}

public extension Build {
    static let noop = Self(
        version: { "test" },
        gitSha: { "0000000" }
    )
}
