//
//  SettingsView.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.glassnodeService) private var service

    private let keychain = KeychainClient()

    @State private var editingKey: String = ""
    @State private var existingKey: String? = nil
    @State private var isEditing: Bool = false
    @State private var isValidating: Bool = false
    @State private var isValid: Bool? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        Form {
            Section(header: Text("Glassnode API Key"), footer:
                        HStack(spacing: 8) {
                if isValidating {
                    ProgressView().controlSize(.small)
                    Text("Checking…")
                } else if let isValid {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(isValid ? .green : .red)
                    Text(isValid ? "API key is valid" : "API key is invalid")
                } else {
                    Text("Status unknown")
                }
            }
            ) {
                if isEditing || (existingKey == nil) {
                    SecureField("Enter API key", text: $editingKey)
                        .autocorrectionDisabled(true)
                    
                    HStack {
                        Button("Save") { saveKey() }
                            .buttonStyle(.borderedProminent)
                        Button("Cancel") { cancelEdit() }
                            .buttonStyle(.bordered)
                            .disabled(existingKey == nil)
                    }
                } else {
                    HStack {
                        Text(anonymizedKey(existingKey ?? ""))
                            .font(.body.monospaced())
                            .textSelection(.disabled)
                        Spacer()
                        Button("Change") { beginEdit() }
                    }
                }
                
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .padding()
        .toolbar() {
            ToolbarItem {
                Button("Get API Key", systemImage: "key.horizontal") {
                    //
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .task { await loadExistingKeyAndValidate() }
    }

    private func loadExistingKeyAndValidate() async {
        do {
            let key = try keychain.readAPIKey()
            await MainActor.run {
                self.existingKey = key
                self.isEditing = (key == nil)
                self.editingKey = ""
                Task { await service.updateCachedAPIKey(key) }
            }
            await validate()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func beginEdit() {
        editingKey = existingKey ?? ""
        isEditing = true
        errorMessage = nil
    }

    private func cancelEdit() {
        isEditing = false
        editingKey = ""
        errorMessage = nil
    }

    private func saveKey() {
        let newKey = editingKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newKey.isEmpty else { self.errorMessage = "API key cannot be empty"; return }
        do {
            try keychain.saveAPIKey(newKey)
            Task { await service.updateCachedAPIKey(newKey) }
            existingKey = newKey
            isEditing = false
            editingKey = ""
            errorMessage = nil
            Task { await validate() }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func validate() async {
        await MainActor.run {
            isValidating = true
            isValid = nil
        }
        let ok = await service.validateAPIKey()
        await MainActor.run {
            isValid = ok
            isValidating = false
        }
    }

    private func anonymizedKey(_ key: String) -> String {
        guard key.count > 10 else { return String(repeating: "•", count: max(4, key.count)) }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
}

#Preview {
    SettingsView()
        .environment(\.glassnodeService, GlassnodeService())
}
