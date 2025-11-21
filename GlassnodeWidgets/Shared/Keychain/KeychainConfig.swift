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

    /// Keychain access group for sharing between app and widget extension.
    /// When using kSecAttrSynchronizable, we don't specify an access group explicitly.
    /// The system automatically uses the first keychain-access-groups value from entitlements,
    /// which is shared between the app and widget extension.
    static let accessGroup: String? = nil
}
