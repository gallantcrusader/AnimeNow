//
//  SettingsView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 12/15/22.
//

import Awesome
import ComposableArchitecture
import DiscordClient
import FluidGradient
import SwiftUI
import ViewComponents

// MARK: - SettingsView

public struct SettingsView: View {
    @Environment(\.openURL)
    var openURL

    @ObservedObject
    var viewStore: ViewStoreOf<SettingsReducer>

    let store: StoreOf<SettingsReducer>

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
        self.viewStore = .init(store) { $0 }
    }

    public var body: some View {
        #if os(iOS)
        StackNavigation(title: "Settings") {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 24) {
                    general
                    accounts
                    discord
                    about
                }
                .padding(.horizontal)
                ExtraBottomSafeAreaInset()
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
        #else
        TabView {
            ScrollView {
                general
                    .padding()
            }
            .tabItem {
                VStack {
                    Image(systemName: "gearshape.fill")
                    Text("General")
                }
            }

            ScrollView {
                accounts
                    .padding()
            }
            .tabItem {
                VStack {
                    Image(systemName: "at")
                    Text("Accounts")
                }
            }

            ScrollView {
                discord
                    .padding()
            }
            .tabItem {
                VStack {
                    Image(systemName: "square.stack.3d.up.fill")
                    Text("Discord")
                }
            }

            ScrollView {
                about
                    .padding()
            }
            .tabItem {
                VStack {
                    Image(systemName: "info")
                    Text("About")
                }
            }
        }
        .onAppear {
            viewStore.send(.onAppear)
        }
        #endif
    }
}

// MARK: - SettingsView + General

extension SettingsView {
    @ViewBuilder
    var general: some View {
        SettingsGroupView(title: "General") {
            SettingsRowView(name: "Provider") {
                ContextButton(
                    items: viewStore.selectableAnimeProviders.items
                        .map { item in
                            .init(
                                name: item.name,
                                image: item.logo.flatMap { .init(string: $0) }
                            )
                        }
                ) { provider in
                    viewStore.send(
                        .binding(
                            .set(\.$userSettings.preferredProvider, provider)
                        )
                    )
                } label: {
                    HStack {
                        if let logo = viewStore.selectableAnimeProviders.item?.logo {
                            CachedAsyncImage(url: .init(string: logo)) { image in
                                image.resizable()
                            } placeholder: {
                                EmptyView()
                            }
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .clipShape(Circle())
                        }

                        Text(viewStore.selectableAnimeProviders.item?.name ?? "Not Selected")
                            .foregroundColor(.white)

                        if !viewStore.selectableAnimeProviders.items.isEmpty {
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
            }
        }
    }
}

// MARK: - SettingsView + Accounts

extension SettingsView {
    @ViewBuilder
    var accounts: some View {
        SettingsGroupView(title: "Accounts") {
            ForEach(viewStore.accounts, id: \.name) { account in
                VStack(spacing: 0) {
                    HStack {
                        Image(account.image)
                            .resizable()
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(account.name)
                                .font(.body.weight(.semibold))
                            Text(account.description)
                                .font(.system(size: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()

                    Group {
                        switch account.authentication {
                        case .unauthenticated:
                            EmptyView()
                        case .authenticating:
                            Text("Authenticating...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 96)
                        case let .authenticated(user):
                            HStack(spacing: 16) {
                                CachedAsyncImage(url: user.profileImage) { image in
                                    image.resizable()
                                } placeholder: {
                                    Awesome.Solid.user.image
                                        .resizable()
                                        .size(48)
                                        .foregroundColor(.white)
                                }
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)

                                VStack(alignment: .leading) {
                                    Text(user.name)
                                        .font(.system(size: 13, weight: .bold))

                                    if let episodesWatched = user.episodesWatched {
                                        Text("Episodes Watched: \(episodesWatched)")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.init(white: 1.0))

                                Spacer()
                            }
                            .padding(.horizontal)
                            .frame(height: 96)
                            .frame(maxWidth: .infinity)
                            .background(
                                CachedAsyncImage(url: user.bannerImage) { phase in
                                    switch phase {
                                    case .empty, .failed:
                                        Color.gray.opacity(0.25)
                                    case let .success(image):
                                        image.resizable()
                                            .interpolation(.high)
                                    }
                                }
                                .scaledToFill()
                                .overlay(Color.black.opacity(0.5))
                            )
                            .clipped()
                        case .failed:
                            Text("Failed to retrieve user info.")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 96)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .background(
                        Color.gray.opacity(0.25)
                    )

                    switch account.authentication {
                    case .unauthenticated:
                        SettingsRowView(name: "Log In") {
                            viewStore.send(account.login)
                        }
                    default:
                        SettingsRowView(name: "Log Out") {
                            viewStore.send(account.logout)
                        }
                        .foregroundColor(.red)
                    }
                }
                .background(
                    FluidGradient(
                        blobs: account.palette,
                        speed: 0.05
                    )
                    .blur(radius: 24)
                )
            }
        }
        .backgroundColor(nil)
        .spacing(12)
        .cornerRadius(12, cornerItems: true)
    }
}

// MARK: - SettingsView + Discord

extension SettingsView {
    @ViewBuilder
    var discord: some View {
        if viewStore.supportsDiscord {
            SettingsGroupView(title: "Discord") {
                SettingsRowView(
                    name: "Enable",
                    active: viewStore.binding(\.$userSettings.discordEnabled)
                )

                if viewStore.userSettings.discordEnabled {
                    SettingsRowView(
                        name: "Status",
                        text: viewStore.discordStatus.rawValue
                    )
                }
            }
            .animation(
                .easeInOut(
                    duration: 0.12
                ),
                value: viewStore.state
            )
        }
    }
}

// MARK: - SettingsView + About

extension SettingsView {
    @ViewBuilder
    var about: some View {
        VStack(spacing: 0) {
            SettingsGroupView(title: "About") {
                SettingsRowView(
                    name: "Clear Cache",
                    text: "\(viewStore.imageCacheUsage / (1_024 * 1_024)) MB / \(viewStore.imageCacheCapacity / (1_024 * 1_024)) MB"
                )
                .foregroundColor(.red)
                .onLongPressGesture {
                    viewStore.send(.resetImageCache)
                }

                SettingsRowView.views(name: "Socials") {
                    VStack(spacing: 12) {
                        Button {
                            openURL(.init(string: "https://github.com/AnimeNow-Team/AnimeNow").unsafelyUnwrapped)
                        } label: {
                            HStack {
                                Awesome.Brand.github.image
                                    .foregroundColor(.white)
                                    .size(24)

                                Text("GitHub")
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                                .foregroundColor(
                                    .init(
                                        red: 0.09,
                                        green: 0.08,
                                        blue: 0.08
                                    )
                                )
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            openURL(.init(string: "https://discord.gg/R5v8Sa3WHE").unsafelyUnwrapped)
                        } label: {
                            HStack {
                                Awesome.Brand.discord.image
                                    .foregroundColor(.white)
                                    .size(24)

                                Text("Join our Discord")
                                    .font(.body.weight(.bold))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 12,
                                    style: .continuous
                                )
                                .foregroundColor(
                                    .init(
                                        .sRGB,
                                        red: 0.4470,
                                        green: 0.5372,
                                        blue: 0.8549
                                    )
                                )
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            openURL(.init(string: "https://www.buymeacoffee.com/animenow").unsafelyUnwrapped)
                        } label: {
                            Text("☕ Buy me a coffee")
                                .font(.body.weight(.bold))
                                .foregroundColor(.black)
                                .padding(12)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: 12,
                                        style: .continuous
                                    )
                                    .foregroundColor(.yellow)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }

            VStack {
                Text("Made with ❤️")
                Text("Version: \(viewStore.buildVersion)")
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(.gray)
            .padding()
            .padding(.bottom)
        }
    }
}

// MARK: - SettingsView_Previews

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(
            store: .init(
                initialState: .init(),
                reducer: EmptyReducer()
            )
        )
        .preferredColorScheme(.dark)
        .frame(width: 300)
        .fixedSize()
    }
}
