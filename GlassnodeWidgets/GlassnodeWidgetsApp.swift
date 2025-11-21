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

    init() {
        // Migrate existing API key to use kSecAttrAccessibleAfterFirstUnlock
        // This ensures widgets can access the key even when device is locked
        let keychainClient = KeychainClient()
        try? keychainClient.migrateAPIKeyAccessibility()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
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
