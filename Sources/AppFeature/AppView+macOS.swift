//
//  AppView.swift
//  Anime Now! (macOS)
//
//  Created by ErrorErrorError on 9/3/22.
//

#if os(macOS)
import ComposableArchitecture
import SwiftUI

extension AppView {
    @ViewBuilder
    var tabBar: some View {
        WithViewStore(store) { state in
            state.route
        } content: { selected in
            HStack(spacing: 32) {
                Text("Anime Now!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    ForEach(
                        AppReducer.Route.allCases,
                        id: \.self
                    ) { route in
                        HStack {
                            Text(route.title)
                                .font(.headline)

                            if route == .downloads {
                                WithViewStore(
                                    store,
                                    observe: \.totalDownloadsCount
                                ) { viewState in
                                    if viewState.state > 0 {
                                        Circle()
                                            .foregroundColor(.secondaryAccent)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Text("\(viewState.state)")
                                                    .font(.callout.bold())
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .foregroundColor(selected.state == route ? Color.white : Color.gray)
                        .clipShape(Capsule())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selected.send(
                                .set(\.$route, route),
                                animation: .linear(duration: 0.15)
                            )
                        }
                    }
                }
            }
            .padding()
            .padding(.horizontal, 40) // Required in order to consider arrow indicators
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                LinearGradient(
                    stops: [
                        .init(
                            color: .black.opacity(0.75),
                            location: 0.0
                        ),
                        .init(
                            color: .clear,
                            location: 1.0
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.container, edges: .top)
            )
        }
    }
}
#endif
