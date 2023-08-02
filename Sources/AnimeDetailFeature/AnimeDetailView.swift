//
//  AnimeDetailView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 9/6/22.
//  Copyright © 2022. All rights reserved.
//

import Awesome
import ComposableArchitecture
import DownloaderClient
import SharedModels
import SwiftUI
import Utilities
import ViewComponents

// MARK: - AnimeDetailView

public struct AnimeDetailView: View {
    let store: StoreOf<AnimeDetailReducer>

    @State
    private var averageImageColor: Color = .black

    public init(store: StoreOf<AnimeDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WithViewStore(
                store,
                observe: \.anime
            ) { viewStore in
                LoadableView(loadable: viewStore.state) { anime in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            topContainer(anime)
                            infoContainer(anime)
                            episodesContainer(anime)
                            Spacer(minLength: 24)
                        }
                    }
                    .background(
                        BlurView()
                            .edgesIgnoringSafeArea(.bottom)
                            .opacity(0.65)
                    )
                } failedView: {
                    VStack(spacing: 16) {
                        Text("Failed to fetch anime content.")
                            .font(.body.bold())
                            .foregroundColor(.white.opacity(0.9))
                        Button {
                            viewStore.send(.retryAnimeFetch)
                        } label: {
                            Text("Retry")
                                .font(.body.weight(.bold))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } waitingView: {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            topContainer(.placeholder)
                            infoContainer(.placeholder)
                            episodesContainer(nil)
                            Spacer(minLength: 24)
                        }
                    }
                    .placeholder(active: true)
                    .disabled(true)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewStore.state.finished)
                .onAppear {
                    viewStore.send(.onAppear)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .overlay(closeButton)
        #if os(iOS)
            .ignoresSafeArea(edges: .top)
            .statusBarHidden()
        #endif
            .background(
                LinearGradient(
                    stops: [
                        .init(
                            color: averageImageColor,
                            location: 0.0
                        ),
                        .init(
                            color: .black,
                            location: 1.0
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
            )
    }
}

// Close button

extension AnimeDetailView {
    @ViewBuilder
    var closeButton: some View {
        Button {
            ViewStore(store.stateless)
                .send(.closeButtonPressed)
        } label: {
            Image(systemName: DeviceUtil.isMac ? "chevron.backward" : "xmark")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(Color.white.opacity(0.9))
                .padding(12)
                .background(BlurView())
                .clipShape(Circle())
                .padding()
        }
        .buttonStyle(.plain)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: DeviceUtil.isMac ? .topLeading : .topTrailing
        )
    }
}

// MARK: AnimeDetailView.PlayButtonState

extension AnimeDetailView {
    private enum PlayButtonState: Equatable, CustomStringConvertible {
        case loading
        case unavailable
        case comingSoon
        case playFromBeginning(EpisodePlayback)
        case playNextEpisode(EpisodePlayback)
        case resumeEpisode(EpisodePlayback)

        init(_ state: AnimeDetailReducer.State) {
            guard state.anime.finished else {
                self = .loading
                return
            }

            guard let anime = state.anime.value else {
                self = .unavailable
                return
            }

            guard anime.status != .upcoming, anime.status != .tba else {
                self = .comingSoon
                return
            }

            guard state.episodes.finished else {
                self = .loading
                return
            }

            guard let episodes = state.episodes.value,
                  let firstEpisode = episodes.first
            else {
                self = .unavailable
                return
            }

            let episodesProgress = state.animeStore.value?.episodes
            let lastUpdatedProgress = episodesProgress?.max(by: \.lastUpdatedProgress)

            if let lastUpdatedProgress,
               let episode = episodes.first(where: { $0.number == lastUpdatedProgress.number }) {
                if !lastUpdatedProgress.almostFinished {
                    self = .resumeEpisode(
                        .init(
                            format: anime.format,
                            episodeNumber: episode.number
                        )
                    )
                    return
                } else if lastUpdatedProgress.almostFinished,
                          episodes.last != episode,
                          let nextEpisode = episodes.first(where: { $0.number == (lastUpdatedProgress.number + 1) }) {
                    self = .playNextEpisode(
                        .init(
                            format: anime.format,
                            episodeNumber: nextEpisode.number
                        )
                    )
                    return
                }
            }

            self = .playFromBeginning(
                .init(
                    format: anime.format,
                    episodeNumber: firstEpisode.number
                )
            )
        }

        var isEnabled: Bool {
            switch self {
            case .loading, .unavailable, .comingSoon:
                return false
            default:
                return true
            }
        }

        var episodeNumber: Episode.ID? {
            switch self {
            case let .playFromBeginning(info),
                 let .playNextEpisode(info),
                 let .resumeEpisode(info):
                return info.episodeNumber
            default:
                return nil
            }
        }

        var description: String {
            switch self {
            case .loading:
                return "Loading..."

            case .unavailable:
                return "Unavailable"

            case .comingSoon:
                return "Coming Soon"

            case let .playFromBeginning(info):
                return "Play \(info.format == .movie ? "Movie" : "")"

            case let .playNextEpisode(info):
                return "Play E\(info.episodeNumber)"

            case let .resumeEpisode(info):
                if info.format == .movie {
                    return "Resume Movie"
                } else {
                    return "Resume E\(info.episodeNumber)"
                }
            }
        }

        var isLoading: Bool {
            self == .loading
        }

        struct EpisodePlayback: Equatable {
            let format: Anime.Format
            var episodeNumber: Episode.ID
        }
    }
}

extension AnimeDetailView {
    @ViewBuilder
    func topContainer(_ anime: Anime) -> some View {
        ZStack {
            FillAspectImage(
                url: (
                    DeviceUtil.isPhone ? anime.posterImage.largest : anime.coverImage.largest ?? anime.posterImage
                        .largest
                )?.link
            )
            .onAverageColor { color in
                averageImageColor = color ?? .black
            }
            .overscrollExpandView()

            VStack(alignment: .leading, spacing: 8) {
                VStack {
                    Text(anime.title)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )

                    HStack(alignment: .top, spacing: 4) {
                        ForEach(
                            anime.categories,
                            id: \.self
                        ) { category in
                            Text(category)
                                .font(.footnote)
                                .bold()
                                .foregroundColor(.white.opacity(0.8))
                            createDot(anime.categories, category)
                        }
                        Spacer()
                    }
                }

                HStack {
                    // MARK: Play Button

                    WithViewStore(
                        store,
                        observe: PlayButtonState.init
                    ) { viewState in
                        ZStack {
                            Button {
                                if let episodeId = viewState.episodeNumber {
                                    viewState.send(.selectedEpisode(episodeId))
                                }
                            } label: {
                                switch viewState.state {
                                case .loading, .unavailable, .comingSoon:
                                    Text(viewState.state.description)
                                case .playFromBeginning, .playNextEpisode, .resumeEpisode:
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text(viewState.state.description)
                                    }
                                }
                            }
                            .buttonStyle(PlayButtonStyle(isEnabled: viewState.isEnabled))
                            .disabled(!viewState.isEnabled)
                        }
                        .animation(.linear(duration: 0.15), value: viewState.state)
                    }

                    Spacer()

                    WithViewStore(
                        store,
                        observe: \.isLoadingAnime
                    ) { viewState in
                        Button {
                            viewState.send(.tappedCollectionList)
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.bold())
                                .foregroundColor(.white)
                                .padding()
                                .background(BlurView())
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }

                    WithViewStore(store) { state in
                        state.animeStore.value?.isFavorite ?? false
                    } content: { isFavoriteViewStore in
                        Button {
                            isFavoriteViewStore.send(.tappedFavorite)
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.body.bold())
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    Group {
                                        if isFavoriteViewStore.state {
                                            Color.red
                                        } else {
                                            BlurView()
                                        }
                                    }
                                )
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
            #if os(macOS)
                .padding(.horizontal, 40)
            #endif
                .background(
                    LinearGradient(
                        stops: [
                            .init(
                                color: .clear,
                                location: 0.0
                            ),
                            .init(
                                color: averageImageColor.opacity(0.5),
                                location: 1.0
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomLeading
                )
        }
        .aspectRatio(
            DeviceUtil.isPhone ? 2 / 3 : DeviceUtil.isPad ? 7 / 3 : 9 / 3,
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func createDot(_ items: [String], _ current: String) -> some View {
        if items.last != current {
            Text("\u{2022}")
                .font(.footnote)
                .fontWeight(.black)
                .foregroundColor(.white.opacity(0.8))
        } else {
            EmptyView()
        }
    }
}

// MARK: - Info Container

extension AnimeDetailView {
    @ViewBuilder
    func infoContainer(_ anime: Anime) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: Description Info

            Text(anime.description)
                .font(.body)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Bubbles info

            HStack {
                if let rating = anime.avgRating {
                    ChipView(
                        text: "\(ceil((rating * 5) / 0.5) * 0.5)"
                    ) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }

                if let year = anime.releaseYear {
                    ChipView(text: "\(year)")
                }

                ChipView(text: anime.format.rawValue)
            }
            .foregroundColor(.white)
            .font(.system(size: 14).bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        #if os(macOS)
            .padding(.horizontal, 40)
        #endif
    }
}

// MARK: Episodes Container

extension AnimeDetailView {
    private struct EpisodesViewState: Equatable {
        let providers: Selectable<ProviderInfo>
        let episodes: Loadable<[Episode]>
        let compact: Bool
        let ascendingOrder: Bool

        init(_ state: AnimeDetailReducer.State) {
            self.providers = state.stream.availableProviders
            self.episodes = state.episodes
            self.compact = state.compactEpisodes
            self.ascendingOrder = !state.episodesDescendingOrder
        }
    }

    @ViewBuilder
    func episodesContainer(_ anime: Anime?) -> some View {
        if anime?.status.canShowEpisodes ?? true {
            WithViewStore(
                store,
                observe: EpisodesViewState.init
            ) { viewState in
                HStack(alignment: .center) {
                    buildSubHeading(title: "Episodes")

                    Spacer()

                    if DeviceUtil.isPhone {
                        HStack(spacing: 8) {
                            Image("rectangle.inset.filled")
                                .foregroundColor(viewState.compact ? .gray : .white)
                                .onTapGesture {
                                    viewState.send(
                                        .toggleCompactEpisodes,
                                        animation: .easeInOut(duration: 0.25)
                                    )
                                }
                                .disabled(!viewState.compact)

                            Image("rectangle.grid.1x2.fill")
                                .foregroundColor(viewState.compact ? .white : .gray)
                                .onTapGesture {
                                    viewState.send(
                                        .toggleCompactEpisodes,
                                        animation: .easeInOut(duration: 0.25)
                                    )
                                }
                                .disabled(viewState.compact)
                        }
                        .font(.body.bold())
                    }

                    HStack(spacing: 8) {
                        Awesome.Solid.sortAmountDownAlt.image
                            .size(20)
                            .foregroundColor(viewState.ascendingOrder ? .white : .gray)
                            .onTapGesture {
                                viewState.send(
                                    .toggleEpisodeOrder,
                                    animation: .easeInOut(duration: 0.25)
                                )
                            }
                            .disabled(viewState.ascendingOrder)

                        Awesome.Solid.sortAmountUp.image
                            .size(20)
                            .foregroundColor(!viewState.ascendingOrder ? .white : .gray)
                            .onTapGesture {
                                viewState.send(
                                    .toggleEpisodeOrder,
                                    animation: .easeInOut(duration: 0.25)
                                )
                            }
                            .disabled(!viewState.ascendingOrder)
                    }
                }
                .padding(.horizontal)
                #if os(macOS)
                    .padding(.horizontal, 40)
                #endif

                HStack {
                    ContextButton(
                        items: viewState.providers.items
                            .map { item in
                                .init(
                                    name: item.name,
                                    image: item.logo.flatMap { .init(string: $0) }
                                )
                            }
                    ) { provider in
                        viewState.send(.stream(.selectProvider(provider)))
                    } label: {
                        HStack {
                            if let logo = viewState.providers.item?.logo {
                                CachedAsyncImage(url: .init(string: logo)) { image in
                                    image.resizable()
                                } placeholder: {
                                    EmptyView()
                                }
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .clipShape(Circle())
                            }

                            Text(viewState.providers.item?.name ?? "Not Selected")
                                .foregroundColor(.white)

                            if !viewState.providers.items.isEmpty {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Capsule().foregroundColor(.gray).opacity(0.25))
                        .clipShape(Capsule())
                        .fixedSize()
                    }

                    Spacer()

                    // TODO: Add option for selecting a list of episodes
                }
                .padding(.horizontal)
                #if os(macOS)
                    .padding(.horizontal, 40)
                #endif

                LoadableView(loadable: viewState.episodes) { episodes in
                    if !episodes.isEmpty {
                        generateEpisodesContainer(
                            viewState.ascendingOrder ? episodes : .init(episodes.reversed()),
                            viewState.compact
                        )
                    } else {
                        VStack {
                            Text("No episodes available from this provider.")
                                .padding()
                            Button(action: {
                                viewState.send(.stream(.retryEpisodeFetch))
                            }) {
                                Label("Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.25))
                            .clipShape(Capsule())
                        }
                        .frame(height: 150)
                    }
                } failedView: {
                    Text("There was an error retrieving episodes from this provider.")
                        .padding()
                        .frame(height: 100)
                } waitingView: {
                    generateEpisodesContainer(
                        Episode.placeholders(8),
                        viewState.compact
                    )
                    .placeholder(active: true)
                    .disabled(true)
                }
                .animation(.linear(duration: 0.12), value: viewState.episodes)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
        }
    }
}

extension AnimeDetailView {
    @ViewBuilder
    private func generateEpisodesContainer(
        _ episodes: [Episode],
        _ compact: Bool
    ) -> some View {
        if DeviceUtil.isPhone {
            LazyVStack(spacing: 12) {
                ForEach(episodes, id: \.id) { episode in
                    generateEpisodeItem(
                        episode,
                        compact: compact
                    )
                }
            }
            .padding(.horizontal)
        } else {
            DynamicHStackScrollView(
                idealWidth: 350,
                items: episodes
            ) { episode in
                generateEpisodeItem(
                    episode,
                    compact: false
                )
            }
        }
    }

    struct EpisodeDownloadingViewState: Equatable {
        let episodeStore: EpisodeStore?
        let downloadStatus: DownloaderClient.Status?

        init(
            _ state: AnimeDetailReducer.State,
            _ episodeNumber: Int
        ) {
            self.episodeStore = !state.isLoadingEpisodes ? state.animeStore.value?.episodes
                .first { $0.number == episodeNumber } : nil
            self.downloadStatus = !state.isLoadingEpisodes ? state.episodesStatus[id: episodeNumber]?.status : nil
        }
    }

    @ViewBuilder
    private func generateEpisodeItem(
        _ episode: Episode,
        compact: Bool
    ) -> some View {
        WithViewStore(store) { state in
            EpisodeDownloadingViewState(state, episode.number)
        } content: { viewState in
            Group {
                if compact {
                    ThumbnailItemCompactView(
                        episode: episode,
                        progress: viewState.episodeStore?.progress,
                        downloadStatus: .init(state: viewState.downloadStatus) { action in
                            switch action {
                            case .download:
                                viewState.send(.downloadEpisode(episode.number))
                            case .cancel:
                                viewState.send(.cancelDownload(episode.number))
                            case .retry:
                                viewState.send(.retryDownload(episode.number))
                            }
                        }
                    )
                    .frame(height: 84)
                    .frame(maxWidth: .infinity)
                } else {
                    ThumbnailItemBigView(
                        episode: episode,
                        progress: viewState.episodeStore?.progress,
                        progressSize: 10,
                        downloadStatus: .init(state: viewState.downloadStatus) { action in
                            switch action {
                            case .download:
                                viewState.send(.downloadEpisode(episode.number))
                            case .cancel:
                                viewState.send(.cancelDownload(episode.number))
                            case .retry:
                                viewState.send(.retryDownload(episode.number))
                            }
                        }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewState.episodeStore?.progress)
            .onTapGesture {
                viewState.send(
                    .selectedEpisode(
                        episode.id
                    )
                )
            }
            .contextMenu {
                if !(viewState.episodeStore?.almostFinished ?? false) {
                    Button {
                        viewState.send(
                            .markEpisodeAsWatched(episode.id),
                            animation: .easeInOut(duration: 0.15)
                        )
                    } label: {
                        Text("Mark as Watched")
                    }
                }

                if (viewState.episodeStore?.progress ?? 0) > 0 {
                    Button {
                        viewState.send(
                            .markEpisodeAsUnwatched(episode.number),
                            animation: .easeInOut(duration: 0.15)
                        )
                    } label: {
                        Text("Unwatch")
                    }
                }

                if case .downloaded = viewState.downloadStatus {
                    Button {
                        viewState.send(.removeDownload(episode.number))
                    } label: {
                        Text("Remove Download")
                    }
                } else if viewState.downloadStatus?.canCancelDownload == true {
                    Button {
                        viewState.send(.cancelDownload(episode.number))
                    } label: {
                        Text("Cancel Download")
                    }
                } else if case .failed = viewState.downloadStatus {
                    Button {
                        viewState.send(.retryDownload(episode.number))
                    } label: {
                        Text("Retry Download")
                    }
                }
            }
        }
    }
}

extension AnimeDetailView {
    @ViewBuilder
    func buildSubHeading(title: String) -> some View {
        Text(title)
            .font(.title2.bold())
            .foregroundColor(.white)
    }
}

// MARK: AnimeDetailView.PlayButtonStyle

extension AnimeDetailView {
    struct PlayButtonStyle: ButtonStyle {
        let isEnabled: Bool

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 13).weight(.heavy))
                .padding()
                .background(isEnabled ? Color.white : Color(white: 0.15))
                .foregroundColor(isEnabled ? .black : .white)
                .clipShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        }
    }
}

// MARK: - AnimeDetailView_Previews

struct AnimeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        AnimeDetailView(
            store: .init(
                initialState: .init(
                    hostname: URL(string: "https://api.consumet.org").unsafelyUnwrapped,
                    animeId: 127_230,
                    availableProviders: .init(items: [])
                ),
                reducer: AnimeDetailReducer()
            )
        )
    }
}

extension Anime.Status {
    var canShowEpisodes: Bool {
        self == .current || self == .finished || self == .unreleased
    }
}

#if os(macOS)
typealias PlatformColor = NSColor
#else
typealias PlatformColor = UIColor
#endif
