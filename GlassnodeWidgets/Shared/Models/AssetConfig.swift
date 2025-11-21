//
//  AssetConfig.swift
//  GlassnodeWidgets
//
//  Created by Ondřej Bárta on 20/11/25.
//

import Foundation
import SwiftUI

struct AssetConfig: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let color: Color
}

// MARK: - Predefined Asset

extension AssetConfig {
    /// All available metrics
    static let allAssets: [AssetConfig] = [
        .btc,
    ]

    static let defaultAsset: AssetConfig = .btc

    /// Bitcoin (BTC)
    static let btc = AssetConfig(
        id: "BTC",
        symbol: "BTC",
        name: "Bitcoin",
        color: Color(red: 247 / 255, green: 147 / 255, blue: 26 / 255)
    )
}
