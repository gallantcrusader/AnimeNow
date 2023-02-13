//
//  AirplayView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 9/23/22.
//

import AVKit
import Foundation
import SwiftUI
import ViewComponents

public struct AirplayView: PlatformAgnosticViewRepresentable {
    public init() {}

    public func makeCoordinator() -> Coordinator {
        .init()
    }

    public func makePlatformView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.delegate = context.coordinator

        #if os(iOS)
        view.prioritizesVideoDevices = true
        view.tintColor = .white
        #elseif os(macOS)
        view.isRoutePickerButtonBordered = false
        view.setRoutePickerButtonColor(.white, for: .normal)
        #endif

        return view
    }

    public func updatePlatformView(_: AVRoutePickerView, context _: Context) {}

    static func dismantlePlatformView(_: AVRoutePickerView, coordinator _: Coordinator) {}

    public class Coordinator: NSObject, AVRoutePickerViewDelegate {
        public func routePickerViewDidEndPresentingRoutes(_: AVRoutePickerView) {}

        public func routePickerViewWillBeginPresentingRoutes(_: AVRoutePickerView) {}
    }
}
