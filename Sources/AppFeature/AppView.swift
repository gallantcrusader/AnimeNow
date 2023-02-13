//
//  AppView.swift
//  Shared
//
//  Created by ErrorErrorError on 9/2/22.
//

import AnimeDetailFeature
import AnimePlayerFeature
import CollectionsFeature
import ComposableArchitecture
import DownloadsFeature
import HomeFeature
import ModalOverlayFeature
import SearchFeature
import SettingsFeature
import SwiftUI

// MARK: - AppView

public struct AppView: View {
    let store: StoreOf<AppReducer>

    public init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    public var body: some View {
        // MARK: Content View

        ZStack {
            WithViewStore(
                store,
                observe: \.route
            ) { viewStore in
                switch viewStore.state {
                case .home:
                    HomeView(
                        store: store.scope(
                            state: \.home,
                            action: AppReducer.Action.home
                        )
                    )

                case .search:
                    SearchView(
                        store: store.scope(
                            state: \.search,
                            action: AppReducer.Action.search
                        )
                    )

                case .collection:
                    CollectionsView(
                        store: store.scope(
                            state: \.collection,
                            action: AppReducer.Action.collection
                        )
                    )

                case .downloads:
                    DownloadsView(
                        store: store.scope(
                            state: \.downloads,
                            action: AppReducer.Action.downloads
                        )
                    )

                case .settings:
                    SettingsView(
                        store: store.scope(
                            state: \.settings,
                            action: AppReducer.Action.settings
                        )
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        #if os(iOS)
        .bottomSafeAreaInset(tabBar)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        #else
        .topSafeAreaInset(tabBar)
        .frame(
            minWidth: 1_000,
            minHeight: 650
        )
        #endif
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .overlay(
            IfLetStore(
                store.scope(
                    state: \.animeDetail,
                    action: AppReducer.Action.animeDetail
                )
            ) { store in
                AnimeDetailView(store: store)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        )
        .overlay(
            IfLetStore(
                store.scope(
                    state: \.modalOverlay,
                    action: AppReducer.Action.modalOverlay
                ),
                then: ModalOverlayView.init
            )
        )
        .overlay(
            IfLetStore(
                store.scope(
                    state: \.videoPlayer,
                    action: AppReducer.Action.videoPlayer
                ),
                then: AnimePlayerView.init
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AppView_Previews

struct AppView_Previews: PreviewProvider {
    static var previews: some View {
        AppView(
            store: .init(
                initialState: .init(),
                reducer: AppReducer()
            )
        )
    }
}
