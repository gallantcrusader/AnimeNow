//
//  BlurView.swift
//  Anime Now! (iOS)
//
//  Created by ErrorErrorError on 9/9/22.
//

import SwiftUI

#if os(iOS)
import UIKit

public typealias BlurEffectView = UIVisualEffectView
public typealias BlurStyle = UIBlurEffect.Style

public var `default` = BlurStyle.systemThinMaterialDark

#else
import AppKit

public typealias BlurEffectView = NSVisualEffectView
public typealias BlurStyle = NSVisualEffectView.Material

public var `default` = BlurStyle.fullScreenUI

#endif


public struct BlurView: PlatformAgnosticViewRepresentable {

    public init(_ style: BlurStyle = `default`) {
        self.style = style
    }

    var style: BlurStyle = `default`

    public func makePlatformView(context: Context) -> BlurEffectView {
        BlurEffectView()
    }

    public func updatePlatformView(_ view: BlurEffectView, context: Context) {
        #if os(iOS)
        view.effect = UIBlurEffect(style: style)
        #else
        view.material = style
        view.blendingMode = .withinWindow
        view.state = .active
        #endif
    }
}


public struct BlurredButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .aspectRatio(1, contentMode: .fill)
            .padding(12)
    }
}
