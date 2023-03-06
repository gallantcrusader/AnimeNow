//
//  File.swift
//
//
//  Created by ErrorErrorError on 2/26/23.
//
//

import Foundation

public extension TrackingListClient {
    enum AuthState: Equatable {
        case unauthenticated
        case authenticated
        case expired

        public var isAuthenticated: Bool {
            self != .unauthenticated
        }
    }
}
