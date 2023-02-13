//
//  Presence.swift
//  SwordRPC
//
//  Created by Spotlight Deveaux on 3/26/22.
//

import Foundation

public extension SwordRPC {
    /// Sets the presence for this RPC connection.
    ///
    /// If the presence is set before RPC is connected, it is discarded.
    ///
    /// - Parameter presence: The presence to display.
    func setPresence(_ presence: RichPresence?) {
        Task.detached { [weak self] in
            guard let self else {
                return
            }

            var args = [String: RequestArg]()
            args["pid"] = .int(.init(self.pid))
            args["activity"] = presence.flatMap { presence in .activity(presence) }

            try? await self.discordSocket?.write(
                Command(
                    cmd: .setActivity,
                    args: args
                ),
                type: .frame
            )
        }
    }
}
