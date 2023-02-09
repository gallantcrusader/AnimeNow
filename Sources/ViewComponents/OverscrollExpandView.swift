//
//  OverscrollExpandView.swift
//  
//
//  Created by ErrorErrorError on 2/8/23.
//  
//

import SwiftUI

struct OverscrollExpandView: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { reader in
            let globalFrame = reader.frame(in: .global)
            content
                .frame(
                    width: reader.size.width,
                    height: reader.size.height + (globalFrame.minY > 0 ? globalFrame.minY : 0),
                    alignment: .center
                )
                .contentShape(Rectangle())
                .clipped()
                .offset(y: globalFrame.minY <= 0 ? 0 : -globalFrame.minY)
        }
    }
}

extension View {
    @ViewBuilder
    public func overscrollExpandView(_ active: Bool = true) -> some View {
        if active {
            self.modifier(OverscrollExpandView())
        } else {
            self
        }
    }
}
