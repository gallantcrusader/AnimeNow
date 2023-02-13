//
//  VideoPlayer.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 12/23/22.
//

import AVFoundation
import AVKit
import Combine
import Foundation
import MediaPlayer
import SwiftUI
import ViewComponents

// MARK: - VideoPlayer

public struct VideoPlayer {
    @Binding
    private var gravity: Gravity
    @Binding
    private var pipActive: Bool

    private let player: AVPlayer
    private var onPictureInPictureStatusChangedCallback: ((PIPStatus) -> Void)?

    public init(
        player: AVPlayer,
        gravity: Binding<Gravity>,
        pipActive: Binding<Bool>
    ) {
        self.player = player
        _gravity = gravity
        _pipActive = pipActive
    }
}

public extension VideoPlayer {
    enum PIPStatus: Equatable {
        case willStart
        case didStart
        case willStop
        case didStop
        case restoreUI
        case failedToStart
    }

    typealias Gravity = AVLayerVideoGravity
}

// MARK: PlatformAgnosticViewRepresentable

extension VideoPlayer: PlatformAgnosticViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        .init(self)
    }

    public func makePlatformView(
        context: Context
    ) -> PlayerView {
        let view = PlayerView(player: player)
        context.coordinator.addDelegate(view)
        return view
    }

    public func updatePlatformView(
        _ platformView: PlayerView,
        context: Context
    ) {
        platformView.updatePlayer(player)
        if platformView.videoGravity != gravity {
            platformView.videoGravity = gravity
        }

        guard let pipController = context.coordinator.controller else {
            return
        }

        if pipActive, !pipController.isPictureInPictureActive {
            pipController.startPictureInPicture()
        } else if !pipActive, pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        }
    }
}

// MARK: VideoPlayer.Coordinator

public extension VideoPlayer {
    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        let videoPlayer: VideoPlayer
        var controller: AVPictureInPictureController?

        init(_ videoPlayer: VideoPlayer) {
            self.videoPlayer = videoPlayer
            super.init()
        }

        func addDelegate(_ view: PlayerView) {
            guard controller == nil else {
                return
            }
            controller = .init(playerLayer: view.playerLayer)
            controller?.delegate = self
        }

        public func pictureInPictureControllerWillStartPictureInPicture(_: AVPictureInPictureController) {
            videoPlayer.onPictureInPictureStatusChangedCallback?(.willStart)
        }

        public func pictureInPictureControllerDidStartPictureInPicture(_: AVPictureInPictureController) {
            videoPlayer.onPictureInPictureStatusChangedCallback?(.didStart)
            videoPlayer.pipActive = true
        }

        public func pictureInPictureControllerWillStopPictureInPicture(_: AVPictureInPictureController) {
            videoPlayer.onPictureInPictureStatusChangedCallback?(.willStop)
        }

        public func pictureInPictureControllerDidStopPictureInPicture(_: AVPictureInPictureController) {
            videoPlayer.onPictureInPictureStatusChangedCallback?(.didStop)
            videoPlayer.pipActive = false
        }

        public func pictureInPictureController(
            _: AVPictureInPictureController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            videoPlayer.onPictureInPictureStatusChangedCallback?(.restoreUI)
            completionHandler(true)
        }

        public func pictureInPictureController(
            _: AVPictureInPictureController,
            failedToStartPictureInPictureWithError _: Error
        ) {
            videoPlayer.onPictureInPictureStatusChangedCallback?(.failedToStart)
            videoPlayer.pipActive = false
        }
    }
}

public extension VideoPlayer {
    func onPictureInPictureStatusChanged(
        _ callback: @escaping (PIPStatus) -> Void
    ) -> Self {
        var view = self
        view.onPictureInPictureStatusChangedCallback = callback
        return view
    }
}

// MARK: VideoPlayer.PlayerView

public extension VideoPlayer {
    final class PlayerView: PlatformView {
        // swiftlint:disable force_cast
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        var player: AVPlayer? {
            get { playerLayer.player }
            set { playerLayer.player = newValue }
        }

        #if os(iOS)
        override public class var layerClass: AnyClass { AVPlayerLayer.self }
        #else
        override public func makeBackingLayer() -> CALayer { AVPlayerLayer() }
        #endif

        var videoGravity: AVLayerVideoGravity {
            get {
                playerLayer.videoGravity
            }
            set {
                playerLayer.videoGravity = newValue
            }
        }

        init(player: AVPlayer) {
            super.init(frame: .zero)
            #if os(macOS)
            wantsLayer = true
            #endif
            self.player = player
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension VideoPlayer.PlayerView {
    func updatePlayer(_ player: AVPlayer) {
        self.player = player
    }
}
