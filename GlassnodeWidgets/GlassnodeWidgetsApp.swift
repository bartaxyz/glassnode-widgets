//
//  GlassnodeWidgetsApp.swift
//  GlassnodeWidgets
//
//  Created by Ondřej Bárta on 15/11/25.
//

import SwiftUI
import SwiftData
import Security

@main
struct GlassnodeWidgetsApp: App {
    let glassnodeService = GlassnodeService()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Glassnode Widgets")
                    .environment(\.glassnodeService, glassnodeService)
#if os(macOS)
                    .frame(width: 480, height: 280)
#endif
            }
        }
#if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 280)
#endif
    }
}
