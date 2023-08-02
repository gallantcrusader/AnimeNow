//  DownloadOptionsView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/24/22.
//

import AnimeStreamLogic
import ComposableArchitecture
import SettingsFeature
import SharedModels
import SwiftUI
import Utilities

// MARK: - DownloadOptionsView

public struct DownloadOptionsView: View {
    let store: StoreOf<DownloadOptionsReducer>

    public init(store: StoreOf<DownloadOptionsReducer>) {
        self.store = store
    }

    public var body: some View {
        LazyVStack(
            alignment: .center,
            spacing: 24
        ) {
            VStack(spacing: 8) {
                Text("Download Options")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("You can select which options you want to download for this episode.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }

            ScrollView {
                WithViewStore(store) { state in
                    AnimeStreamViewState(state.stream)
                } content: { viewState in
                    SettingsGroupView {
                        SettingsRowView.listSelection(
                            name: "Provider",
                            selectable: viewState.availableProviders
                        ) { provider in
                            viewState.send(.animeStream(.selectProvider(provider)))
                        } itemView: { provider in
                            Text(provider.name)
                        }

                        SettingsRowView.listSelection(
                            name: "Audio",
                            selectable: viewState.links,
                            loading: viewState.loadingLink
                        ) { link in
                            viewState.send(.animeStream(.selectLink(link)))
                        } itemView: { link in
                            Text(link.description)
                        }

                        SettingsRowView.listSelection(
                            name: "Quality",
                            selectable: viewState.sources,
                            loading: viewState.loadingLink || !viewState.links.items.isEmpty && viewState.loadingSource
                        ) { source in
                            viewState.send(.animeStream(.selectSource(source)))
                        } itemView: { source in
                            Text(source.quality.description)
                        }
                    }
                    .animation(.easeInOut, value: viewState.state)
                }
            }

            WithViewStore(
                store,
                observe: \.canDownload
            ) { viewStore in
                Button {
                    viewStore.send(.downloadClicked)
                } label: {
                    Text("Download")
                        .font(.body.bold())
                        .foregroundColor(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewStore.state ? Color.white : Color.gray)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!viewStore.state)
                .animation(.easeInOut, value: viewStore.state)
            }
        }
        .onAppear {
            ViewStore(store).send(.onAppear)
        }
    }
}

// MARK: - DownloadOptionsView_Previews

struct DownloadOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadOptionsView(
            store: .init(
                initialState: .init(
                    hostname: URL(string: "https://api.consumet.org").unsafelyUnwrapped,
                    anime: Anime.attackOnTitan,
                    episodeId: 1,
                    availableProviders: .init(
                        items: []
                    )
                ),
                reducer: DownloadOptionsReducer()
            )
        )
        .padding(24)
        .background(Color(white: 0.12))
        .preferredColorScheme(.dark)
    }
}
