//
//  File.swift
//
//
//  Created by ErrorErrorError on 12/30/22.
//
//

import Foundation

public extension DiscordClient {
    static let noop: Self = .init(
        isActive: false,
        isConnected: false,
        status: { .never },
        setActive: { _ in },
        setActivity: { _ in }
    )
}
