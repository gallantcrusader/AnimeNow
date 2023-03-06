//
//  File.swift
//
//
//  Created by ErrorErrorError on 12/30/22.
//
//

#if os(macOS)

import APIClient
import ComposableArchitecture
import Foundation
import SwordRPC

public extension DiscordClient {
    private static let discordClientKey: String = {
        let encoded: [UInt8] = [
            0x09, 0xAE, 0xC4, 0x54, 0xCB,
            0x6C, 0xE6, 0x5A, 0x3D, 0x85,
            0xB1, 0x93, 0x2F, 0x9B, 0x7E,
            0x70, 0xCE, 0xFA, 0xAE
        ]
        return decode(encoded, cipher: salt)
    }()

    private static let salt: [UInt8] = [
        0x38, 0x9E, 0xF1, 0x6C, 0xFB, 0x54, 0xD2, 0x6F,
        0x0A, 0xBD, 0x84, 0xA3, 0x18, 0xAD, 0x4D, 0x46,
        0xF9, 0xCF, 0x98, 0x1B, 0x3F, 0x84, 0xCF, 0x14,
        0xAF, 0x1C, 0x7D, 0x74, 0x4F, 0x96, 0x8F, 0x87,
        0xEC, 0xE9, 0x6A, 0xE0, 0x96, 0xA2, 0x44, 0x42,
        0x50, 0xE5, 0xD2, 0x31, 0x0F, 0xA3, 0xBE, 0x95,
        0x6E, 0xEA, 0x96, 0xE5, 0x11, 0xC1, 0x50, 0xEE,
        0xBE, 0xE6, 0x72, 0xD7, 0x68, 0x5F, 0x6B, 0xA4
    ]

    private static func decode(
        _ encoded: [UInt8],
        cipher: [UInt8]
    ) -> String {
        .init(
            decoding: encoded.enumerated()
                .map { $0.element ^ cipher[$0.offset % cipher.count] },
            as: UTF8.self
        )
    }

    static let liveValue: Self = {
        let sword = SwordRPC(
            appId: Self.discordClientKey,
            maxRetryCount: 0
        )

        return .init(isActive: sword.isRunning, isConnected: sword.isConnected) {
            .init { continuation in
                let task = Task.detached {
                    while true {
                        if sword.isRunning {
                            if sword.isConnected {
                                continuation.yield(.connected)
                            } else {
                                continuation.yield(.failed)
                            }
                        } else {
                            continuation.yield(.offline)
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000 * 5)
                    }
                }

                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        } setActive: { active in
            if active, !sword.isRunning {
                sword.start()
            } else if !active, sword.isRunning {
                sword.stop()
            }
        } setActivity: { activity in
            switch activity {
            case .none:
                sword.setPresence(nil)

            case let .some(.watching(info)):
                var presence = RichPresence()
                presence.state = info.name
                presence.details = info.episode
                presence.assets.largeText = info.episode
                presence.assets.largeImage = info.image
                presence.assets.smallImage = "logo"
                presence.assets.smallText = "Anime Now!"

                if info.duration > 0 {
                    let main = Date()
                    let currentProgress = info.progress * info.duration
                    presence.timestamps.start = main - currentProgress
                    presence.timestamps.end = main + info.duration - currentProgress
                }

                var button = RichPresence.Button()
                button.label = "Watch Now"
                button.url = "https://animenow.app"
                presence.buttons.append(button)

                sword.setPresence(presence)

            case .some:
                break
            }
        }
    }()
}

#endif
