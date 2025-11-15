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
            SettingsView()
                .navigationTitle("Glassnode Widgets")
                .environment(\.glassnodeService, glassnodeService)
                .frame(width: 480, height: 280)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 280)
    }
}
