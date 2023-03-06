//
//  AnimeNowApp.swift
//  Shared
//
//  Created by ErrorErrorError on 9/2/22.
//

#if os(macOS)
import AppFeature
import ComposableArchitecture
import SettingsFeature
import SwiftUI

@main
struct AnimeNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        WindowGroup {
            AppView(
                store: appDelegate.store
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.expanded)
        .commands {
            CommandGroup(replacing: .newItem) {
                EmptyView()
            }
            CommandGroup(after: .appInfo) {
                Button {} label: {
                    Text("Check for Updates...")
                }
            }
        }

        Settings {
            SettingsView(
                store: appDelegate.store.scope(
                    state: \.settings,
                    action: AppReducer.Action.settings
                )
            )
            .frame(width: 450, height: 400)
        }
    }
}
#endif
