//
//  CastMediaStatus.swift
//  OpenCastSwift
//
//  Created by Miles Hollingsworth on 4/22/18
//  Copyright © 2018 Miles Hollingsworth. All rights reserved.
//

import Foundation
import SwiftyJSON

// MARK: - CastMediaPlayerState

public enum CastMediaPlayerState: String {
    case buffering = "BUFFERING"
    case playing = "PLAYING"
    case paused = "PAUSED"
    case stopped = "STOPPED"
}

// MARK: - CastMediaStatus

public final class CastMediaStatus: NSObject {
    public struct MediaStatusMedia {
        public let duration: Double

        init?(mediaOptions: JSON) {
            guard let duration = mediaOptions["duration"].double else {
                return nil
            }
            self.duration = duration
        }
    }

    public let mediaSessionId: Int
    public let playbackRate: Int
    public let playerState: CastMediaPlayerState
    public let currentTime: Double
    public let metadata: JSON?
    public let contentID: String?
    public let media: MediaStatusMedia?

    private let createdDate = Date()

    public var adjustedCurrentTime: Double {
        currentTime - Double(playbackRate) * createdDate.timeIntervalSinceNow
    }

    public var state: String {
        playerState.rawValue
    }

    override public var description: String {
        "MediaStatus(mediaSessionId: \(mediaSessionId), playbackRate: \(playbackRate), playerState: \(playerState.rawValue), currentTime: \(currentTime))"
    }

    init(json: JSON) {
        self.mediaSessionId = json[CastJSONPayloadKeys.mediaSessionId].int ?? 0

        self.playbackRate = json[CastJSONPayloadKeys.playbackRate].int ?? 1

        self.playerState = json[CastJSONPayloadKeys.playerState].string.flatMap(CastMediaPlayerState.init) ?? .buffering

        self.currentTime = json[CastJSONPayloadKeys.currentTime].double ?? 0

        self.metadata = json[CastJSONPayloadKeys.media][CastJSONPayloadKeys.metadata]

        self.media = MediaStatusMedia(mediaOptions: json[CastJSONPayloadKeys.media])

        if let contentID = json[CastJSONPayloadKeys.media][CastJSONPayloadKeys.contentId].string,
           let data = contentID.data(using: .utf8) {
            self.contentID = (try? JSON(data: data))?[CastJSONPayloadKeys.contentId].string ?? contentID
        } else {
            self.contentID = nil
        }

        super.init()
    }
}
