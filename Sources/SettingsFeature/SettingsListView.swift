//  SettingsListView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/24/22.
//
//

import SwiftUI
import Utilities

// MARK: - SettingsListView

public struct SettingsListView<I: Identifiable & CustomStringConvertible>: View {
    var items: [I]?
    var selected: I.ID?
    var selectedItem: ((I.ID) -> Void)?

    public init(
        items: [I]? = nil,
        selected: I.ID? = nil,
        selectedItem: ((I.ID) -> Void)? = nil
    ) {
        self.items = items
        self.selected = selected
        self.selectedItem = selectedItem
    }

    public var body: some View {
        if let items {
            VStack {
                ForEach(items, id: \.id) { item in
                    Text(item.description)
                        .font(.callout.bold())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem?(item.id)
                        }
                        .background(item.id == selected ? Color.primaryAccent : Color.clear)
                        .cornerRadius(12)
                }
            }
            .transition(
                .move(edge: .trailing)
                    .combined(with: .opacity)
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
    }
}

// MARK: - SettingsListView_Previews

struct SettingsListView_Previews: PreviewProvider {
    private enum Setting: String, Identifiable, CustomStringConvertible {
        case about
        case discord

        var id: String { rawValue }
        var description: String { rawValue }
    }

    static var previews: some View {
        SettingsListView(
            items: [Setting.about, Setting.discord]
        )
    }
}
