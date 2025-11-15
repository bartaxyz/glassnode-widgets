//
//  KeychainConfig.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import Foundation

/// Central place to configure Keychain parameters used in the app.
enum KeychainConfig {
    /// A service identifier for the API key item.
    static let service: String = "GlassnodeAPI"

    /// The account name for the API key item.
    static let account: String = "apiKey"

    /// Optional Keychain access group. Provide this if you want to share the key
    /// with extensions/widgets via Keychain Sharing. Leave `nil` to use the app's default keychain.
    /// Example value: "ABCD1234.com.your.bundleid.keychain"
    ///
    /// Note: You mentioned Keychain Sharing is enabled already. If you want to share the key,
    /// set this to your actual access group string from your entitlements.
    static let accessGroup: String? = nil
}
