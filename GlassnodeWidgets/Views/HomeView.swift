//
//  SettingsView.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import SwiftUI

struct HomeView: View {
    private let keychain = KeychainClient()
    
    @State private var existingKey: String? = nil
    @State var isSettingsOpen: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                if existingKey != nil {
                    MetricsPreviewView()
                        .environmentObject(keychain)
                }
            }
            .toolbar() {
                ToolbarItem {
                    Button("Setup API Key", systemImage: "key.horizontal") {
                        isSettingsOpen = true
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            .navigationTitle("Pulses")
            .sheet(isPresented: $isSettingsOpen) {
                NavigationView {
                    SettingsView()
                }
            }
            .task { await loadExistingKey() }
        }
    }
    
    
    private func loadExistingKey() async {
        do {
            let key = try keychain.readAPIKey()
            await MainActor.run {
                self.existingKey = key
            }
        } catch {
            //
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.glassnodeService, GlassnodeService())
}
