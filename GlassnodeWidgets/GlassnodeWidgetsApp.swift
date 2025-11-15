//
//  GlassnodeWidgetsApp.swift
//  GlassnodeWidgets
//
//  Created by Ondřej Bárta on 15/11/25.
//

import SwiftUI
import SwiftData

@main
struct GlassnodeWidgetsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
