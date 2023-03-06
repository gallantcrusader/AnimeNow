//
//  File.swift
//
//
//  Created by ErrorErrorError on 2/9/23.
//
//

import SwiftUI

// MARK: - DynamicHStackScrollView

public struct DynamicHStackScrollView<T, C: RandomAccessCollection<T>, V: View, L: View>: View where C.Index == Int {
    private let items: C
    private let itemContent: (T) -> V
    private let label: () -> L

    private let idealWidth: CGFloat
    private let spacing: CGFloat

    #if os(macOS)
    @State
    private var visibleRange: Range<Int> = 0..<0
    @State
    private var actualWidth: CGFloat = 0.0
    #endif

    private var emptyCollectionPlaceholder: String?

    public init(
        idealWidth: CGFloat,
        spacing: CGFloat = 12,
        items: C,
        @ViewBuilder itemContent: @escaping (T) -> V,
        @ViewBuilder label: @escaping () -> L
    ) {
        self.idealWidth = idealWidth
        self.spacing = spacing
        self.items = items
        self.itemContent = itemContent
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading) {
            label()
                .padding(.horizontal)
            #if os(macOS)
                .padding(.horizontal, 40)
            #endif
            container
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    var noItemsAvailable: some View {
        VStack(alignment: .center) {
            Text("No items available")
                .font(.system(size: 15, weight: .bold))

            if let emptyCollectionPlaceholder {
                Text(emptyCollectionPlaceholder)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(.horizontal)
    }

    public func emptyItems(placeholder: String) -> DynamicHStackScrollView {
        var view = self
        view.emptyCollectionPlaceholder = placeholder
        return view
    }
}

public extension DynamicHStackScrollView {
    init(
        idealWidth: CGFloat,
        spacing: CGFloat = 12,
        items: C,
        @ViewBuilder itemContent: @escaping (T) -> V
    ) where L == EmptyView {
        self.init(
            idealWidth: idealWidth,
            spacing: spacing,
            items: items,
            itemContent: itemContent
        ) {
            EmptyView()
        }
    }
}

#if os(iOS)
extension DynamicHStackScrollView {
    @ViewBuilder
    var container: some View {
        if items.isEmpty {
            noItemsAvailable
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(items.indices, id: \.self) { index in
                        itemContent(items[index])
                            .frame(width: idealWidth)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#elseif os(macOS)
extension DynamicHStackScrollView {
    @ViewBuilder
    var container: some View {
        if items.isEmpty {
            noItemsAvailable
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: spacing) {
                    ForEach(items.bounds[visibleRange], id: \.self) { index in
                        if items.indices.contains(index) {
                            itemContent(items[index])
                                .frame(width: max(0, actualWidth))
                        }
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            recalculate(proxy)
                        }
                        .onChange(of: idealWidth) { _ in
                            recalculate(proxy)
                        }
                        .onChange(of: spacing) { _ in
                            recalculate(proxy)
                        }
                        .onChange(of: proxy.size) { _ in
                            recalculate(proxy)
                        }
                        .onChange(of: items.count) { _ in
                            recalculate(proxy)
                        }
                }
            )
            .arrowIndicators($visibleRange, items.bounds, shiftBy: 1)
        }
    }

    private func recalculateVisibleRange(_ maxItems: Int) {
        if visibleRange.count != items.bounds.prefix(maxItems).count {
            if items.bounds.contains(visibleRange.lowerBound) {
                // Okay, safe to reuse visibleRange's lower bounds
                let itemsRemaining = items.bounds[visibleRange.lowerBound...]

                if itemsRemaining.count < maxItems {
                    visibleRange = items.bounds[..<itemsRemaining.upperBound].suffix(maxItems)
                } else {
                    visibleRange = visibleRange.lowerBound..<itemsRemaining.prefix(maxItems).upperBound
                }
            } else {
                visibleRange = items.bounds.prefix(maxItems)
            }
        }
    }

    private func recalculate(_ proxy: GeometryProxy) {
        let maxFittingItems = round(proxy.size.width / idealWidth)
        let widthRemaining = proxy.size.width - (idealWidth * maxFittingItems)
        let totalSpacing = maxFittingItems * spacing
        let actualWidthRemainingPerItem = (widthRemaining - totalSpacing) / maxFittingItems
        actualWidth = actualWidthRemainingPerItem + idealWidth
        recalculateVisibleRange(Int(maxFittingItems))
    }
}

extension RandomAccessCollection {
    var bounds: Range<Self.Index> {
        startIndex..<endIndex
    }
}

#endif
