//
//  AnimeCarousel.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 10/17/22.
//
//  Modified version of https://github.com/manuelduarte077/CustomCarouselList/blob/main/Shared/View/SnapCarousel.swift

import Foundation
import IdentifiedCollections
import SharedModels
import SwiftUI
import Utilities

public struct AnimeCarousel<Content: View, T: AnimeRepresentable>: View {
    @Binding var position: Int

    var list: [T]
    var content: (T) -> Content

    public init(
        position: Binding<Int>,
        items: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self._position = position
        self.list = items
        self.content = content
    }

    // Offset...
    @GestureState private var translation: CGFloat = 0

    public var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                // TODO: Find a fix for LazyHStack's weird scrolling behavior
                LazyHStack(spacing: 0) {
                    ForEach(list) { item in
                        content(item)
                            .frame(width: proxy.size.width)
                    }
                }
                .offset(x: CGFloat(position) * -proxy.size.width)
                .offset(x: translation)
                .highPriorityGesture(
                    DragGesture()
                        .updating($translation) { value, out, _ in
                            let leftOverscrol = position == 0 && value.translation.width > 0
                            let rightOverscroll = position == list.count - 1 && value.translation.width < 0
                            let shouldRestrict = leftOverscrol || rightOverscroll
                            out = value.translation.width / (shouldRestrict ? log10(abs(value.translation.width)) : 1)
                        }
                        .onEnded { value in
                            let offset = -(value.translation.width / proxy.size.width)
                            let roundIndex: Int

                            if abs(value.translation.width) > proxy.size.width / 2 {
                                roundIndex = offset > 0 ? 1 : -1
                            } else {
                                roundIndex = 0
                            }

                            position = max(min(position + roundIndex, list.count - 1), 0)
                        }
                )
            }

            VStack(spacing: 8) {
                // Title Name
                ZStack {
                    if let anime, translation == .zero {
                        Text(anime.title)
                            .font(.title.weight(.bold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        EmptyView()
                    }
                }

                // Indicators
                HStack(spacing: 6) {
                    ForEach(
                        indicatorStates
                    ) { state in
                        if state.size != .gone {
                            Circle()
                                .fill(Color.white.opacity(state.selected ? 1 : 0.5))
                                .frame(width: 6, height: 6)
                                .scaleEffect(state.scale)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    .opacity(anime != nil && translation == .zero ? 1.0 : 0)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(DeviceUtil.isPhone ? 0 : 32)
        .animation(.easeInOut, value: translation == .zero)
        #if os(macOS)
        .arrowIndicators(
            $position,
            count: list.count
        )
        #endif
    }
}

extension AnimeCarousel {
    private var anime: T? {
        list[safe: position]
    }
}

extension AnimeCarousel {
    struct IndicatorState: Hashable, Identifiable {
        let id: Int
        var size: Size

        enum Size: Hashable {
            case gone
            case smallest
            case small
            case normal
            case selected
        }

        var scale: Double {
            switch size {
            case .gone:
                return 0
            case .smallest:
                return 0.5
            case .small:
                return 0.75
            case .normal:
                return 1.0
            case .selected:
                return 1.4
            }
        }

        var selected: Bool {
            size == .selected
        }
    }

    private var indicatorStates: [IndicatorState] {
        guard !list.isEmpty && position >= 0 && position < list.indices.count else {
            return []
        }

        var indicatorStates = list.indices.map { IndicatorState(id: $0, size: .gone) }
        let indicatorCount = indicatorStates.count

        let maxIndicators = 9

        let halfMaxIndicators = Int(floor(Double(maxIndicators) / 2))
        let halfMaxIndicatorsCeil = Int(ceil(Double(maxIndicators) / 2))

        let leftSideCount = position - halfMaxIndicators
        let rightSideCount = position + halfMaxIndicatorsCeil

        let addMissingLeftSideItems = leftSideCount < 0 ? abs(leftSideCount) : 0
        let addMissingRightSideItems = rightSideCount > indicatorCount ? rightSideCount - indicatorCount : 0

        let startIndex = max(leftSideCount - addMissingRightSideItems, 0)
        let endIndex = min(rightSideCount + addMissingLeftSideItems, indicatorCount)

        for index in startIndex..<endIndex {
            if (startIndex == index && leftSideCount == 0) || (startIndex + 1 == index && leftSideCount >= 1) {
                indicatorStates[index].size = .small
            } else if startIndex == index && leftSideCount >= 1 {
                indicatorStates[index].size = .smallest
            } else if (endIndex - 2 == index && rightSideCount < indicatorCount) || (endIndex - 1 == index && rightSideCount == indicatorCount) {
                indicatorStates[index].size = .small
            } else if endIndex - 1 == index && rightSideCount < indicatorCount {
                indicatorStates[index].size = .smallest
            } else {
                indicatorStates[index].size = .normal
            }
        }

        indicatorStates[position].size = .selected

        return indicatorStates
    }
}
