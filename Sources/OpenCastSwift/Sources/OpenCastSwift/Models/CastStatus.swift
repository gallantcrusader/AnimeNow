//
//  CastStatus.swift
//  OpenCastSwift
//
//  Created by Miles Hollingsworth on 4/22/18
//  Copyright © 2018 Miles Hollingsworth. All rights reserved.
//

import Foundation
import SwiftyJSON

// MARK: - CastStatus

public final class CastStatus: NSObject {
    public var volume: Double = 1
    public var muted: Bool = false
    public var apps: [CastApp] = []

    override public var description: String {
        "CastStatus(volume: \(volume), muted: \(muted), apps: \(apps))"
    }
}

extension CastStatus {
    convenience init(json: JSON) {
        self.init()
        //        print(json)
        let status = json[CastJSONPayloadKeys.status]
        let volume = status[CastJSONPayloadKeys.volume]

        if let volume = volume[CastJSONPayloadKeys.level].double {
            self.volume = volume
        }
        if let muted = volume[CastJSONPayloadKeys.muted].bool {
            self.muted = muted
        }

        if let apps = status[CastJSONPayloadKeys.applications].array {
            self.apps = apps.compactMap(CastApp.init)
        }
    }
}
