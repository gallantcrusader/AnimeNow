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
    static let liveValue: Self = {
        let sword = SwordRPC(
            appId: AnimeNowAPI.discordClientKey,
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
