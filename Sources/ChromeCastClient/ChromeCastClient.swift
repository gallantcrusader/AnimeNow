//
//  ChromeCastClient.swift
//
//
//  Created by ErrorErrorError on 12/29/22.
//
//

import ComposableArchitecture
import Foundation

// MARK: - ChromeCastClient

public struct ChromeCastClient {
    public let scan: (Bool) -> Void
    public let scannedDevices: () -> AsyncStream<[Device]>
}

// MARK: ChromeCastClient.Device

public extension ChromeCastClient {
    struct Device {
        let id: String
        let name: String
    }
}

// MARK: DependencyKey

extension ChromeCastClient: DependencyKey {}

public extension DependencyValues {
    var chromeCastClient: ChromeCastClient {
        get { self[ChromeCastClient.self] }
        set { self[ChromeCastClient.self] = newValue }
    }
}
