//
//  RichPresence.swift
//  SwordRPC
//
//  Created by Alejandro Alonso
//  Copyright © 2017 Alejandro Alonso. All rights reserved.
//

import Foundation

// MARK: - RichPresence

public struct RichPresence: Encodable {
    public var state = ""
    public var details = ""
    public var assets = Assets()
    public var party = Party()
    public var timestamps = Timestamps()
    public var buttons: [Button] = []
    public var instance = true

    public init() {}

    enum CodingKeys: CodingKey {
        case assets
        case details
        case instance
        case party
        case state
        case timestamps
        case buttons
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(assets, forKey: .assets)
        try container.encode(details, forKey: .details)
        try container.encode(instance, forKey: .instance)
        try container.encode(party, forKey: .party)
        try container.encode(state, forKey: .state)
        try container.encode(timestamps, forKey: .timestamps)

        if !buttons.isEmpty, !buttons.contains(where: { $0.label.isEmpty || $0.url.isEmpty }) {
            try container.encode(buttons, forKey: .buttons)
        }
    }
}

public extension RichPresence {
    struct Timestamps: Encodable {
        public var end: Date?
        public var start: Date?

        enum CodingKeys: String, CodingKey {
            case end
            case start
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encodeIfPresent(start.map { Int($0.timeIntervalSince1970 * 1_000) }, forKey: .start)
            try container.encodeIfPresent(end.map { Int($0.timeIntervalSince1970 * 1_000) }, forKey: .end)
        }
    }

    struct Assets: Encodable {
        public var largeImage: String?
        public var largeText: String?
        public var smallImage: String?
        public var smallText: String?

        enum CodingKeys: String, CodingKey {
            case largeImage = "large_image"
            case largeText = "large_text"
            case smallImage = "small_image"
            case smallText = "small_text"
        }
    }

    struct Party: Encodable {
        public var id: String?
        public var max: Int?
        public var size: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case size
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(id, forKey: .id)

            guard let max = self.max, let size else {
                return
            }

            try container.encode([size, max], forKey: .size)
        }
    }

    struct Button: Encodable {
        public var label: String = ""
        public var url: String = ""

        public init() {}
    }
}
