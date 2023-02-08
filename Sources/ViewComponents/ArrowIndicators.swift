//
//  File.swift
//  
//
//  Created by ErrorErrorError on 2/7/23.
//  
//

import SwiftUI

public struct ArrowIndicatorsModifier: ViewModifier {
    let previous: () -> Void
    let next: () -> Void

    var leftDisabled = false
    var rightDisabled = false

    @State private var hovering = false

    public init(
        previous: @escaping () -> Void,
        next: @escaping () -> Void
    ) {
        self.previous = previous
        self.next = next
    }
    
    public func body(content: Content) -> some View {
        HStack {
            buildArrow("chevron.compact.left") {
                withAnimation {
                    previous()
                }
            }
            .disabled(leftDisabled)

            content
                .clipped()
                .contentShape(Rectangle())

            buildArrow("chevron.compact.right") {
                withAnimation {
                    next()
                }
            }
            .disabled(rightDisabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { isHovering in
            withAnimation {
                hovering = isHovering
            }
        }
    }

    @ViewBuilder
    private func buildArrow(
        _ systemName: String,
        action: @escaping () -> Void
    ) -> some View  {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 32, weight: .regular))
                .frame(maxHeight: .infinity)
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(hovering ? 1.0 : 0)
    }

    public func leftDisabled(_ disabled: Bool) -> ArrowIndicatorsModifier {
        var copy = self
        copy.leftDisabled = disabled
        return copy
    }

    public func rightDisabled(_ disabled: Bool) -> ArrowIndicatorsModifier {
        var copy = self
        copy.rightDisabled = disabled
        return copy
    }
}

public extension View {
    func arrowIndicators(
        _ position: Binding<Int>,
        count: Int
    ) -> some View {
        self.modifier(
            ArrowIndicatorsModifier(
                previous: {
                    position.wrappedValue -= 1
                }, next: {
                    position.wrappedValue += 1
                }
            )
            .leftDisabled(position.wrappedValue <= 0)
            .rightDisabled(position.wrappedValue >= count - 1)
        )
    }

    // TODO: Make indicators work on collection with identifiable
    func arrowIndicators<T: Identifiable, C: Collection>(
        _ items: C
    ) -> some View where C.Element == T {
        self.modifier(
            ArrowIndicatorsModifier(
                previous: {
                }, next: {
                }
            )
//            .leftEnabled(items.first != )
//            .rightEnabled(items.last != )
        )
    }
}
