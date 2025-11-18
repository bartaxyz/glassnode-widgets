//
//  MetricConfig.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 18/11/25.
//

import Foundation
import SwiftUI

/// Configuration for a Glassnode metric
struct MetricConfig: Identifiable, Codable {
    let id: String              // API metric ID (e.g., "market/price_usd_close")
    let name: String            // Display name
    let shortName: String       // Short name for compact displays
    let unit: MetricUnit        // Unit type
    let visualRange: VisualRange // Visualization range
    let color: MetricColor      // Primary color for the metric

    /// API path for this metric
    var apiPath: String {
        "/v1/metrics/\(id)"
    }
}

/// Unit type for metrics
enum MetricUnit: String, Codable {
    case usd                    // USD currency
    case percentage             // Percentage (0-100)
    case ratio                  // Ratio (typically 0-5)
    case count                  // Whole number count
    case hashRate               // Hash rate (H/s)
    case btc                    // Bitcoin amount

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .percentage: return "%"
        case .ratio: return ""
        case .count: return ""
        case .hashRate: return "EH/s"
        case .btc: return "BTC"
        }
    }

    var formatStyle: MetricFormatStyle {
        switch self {
        case .usd: return .currency
        case .percentage: return .percentage
        case .ratio: return .decimal(places: 2)
        case .count: return .integer
        case .hashRate: return .hashRate
        case .btc: return .decimal(places: 2)
        }
    }
}

/// Format style for metric values
enum MetricFormatStyle {
    case currency
    case percentage
    case decimal(places: Int)
    case integer
    case hashRate
}

/// Visual range configuration for charts
enum VisualRange: Codable {
    case fixed(min: Double, max: Double)    // Fixed range (e.g., 0-100 for percentages)
    case dynamic(padding: Double)            // Dynamic based on data with padding %

    func calculateRange(for data: [Double]) -> ClosedRange<Double> {
        switch self {
        case .fixed(let min, let max):
            return min...max
        case .dynamic(let paddingPercent):
            guard !data.isEmpty else { return 0...1 }
            let minValue = data.min() ?? 0
            let maxValue = data.max() ?? 1
            let range = maxValue - minValue
            let padding = range * paddingPercent
            return (minValue - padding)...(maxValue + padding)
        }
    }
}

/// Color configuration for metrics
enum MetricColor: String, Codable {
    case orange     // Bitcoin orange
    case blue       // Default blue
    case green      // Positive/growth metrics
    case purple     // Alternative color
    case red        // Warning/negative metrics

    var primaryColor: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .red: return .red
        }
    }

    var secondaryColor: Color {
        switch self {
        case .orange: return .yellow
        case .blue: return .cyan
        case .green: return .mint
        case .purple: return .indigo
        case .red: return .pink
        }
    }
}

// MARK: - Predefined Metrics

extension MetricConfig {
    /// All available metrics
    static let allMetrics: [MetricConfig] = [
        .price,
        .marketCap,
        .supplyInProfit,
        .activeAddresses,
        .transactionCount,
        .mvrv,
        .hashRate,
        .supplyActive1Year,
        .sopr,
        .fearGreed
    ]

    /// Price (USD)
    static let price = MetricConfig(
        id: "market/price_usd_close",
        name: "Price",
        shortName: "Price",
        unit: .usd,
        visualRange: .dynamic(padding: 0.1),
        color: .orange
    )

    /// Market Capitalization (USD)
    static let marketCap = MetricConfig(
        id: "market/marketcap_usd",
        name: "Market Cap",
        shortName: "Market Cap",
        unit: .usd,
        visualRange: .dynamic(padding: 0.1),
        color: .blue
    )

    /// Percent Supply in Profit
    static let supplyInProfit = MetricConfig(
        id: "supply/profit_relative",
        name: "Percent Supply in Profit",
        shortName: "Supply in Profit",
        unit: .percentage,
        visualRange: .fixed(min: 0, max: 1),
        color: .green
    )

    /// Active Addresses
    static let activeAddresses = MetricConfig(
        id: "addresses/active_count",
        name: "Active Addresses",
        shortName: "Active Addresses",
        unit: .count,
        visualRange: .dynamic(padding: 0.15),
        color: .blue
    )

    /// Transaction Count
    static let transactionCount = MetricConfig(
        id: "transactions/count",
        name: "Transaction Count",
        shortName: "Transactions",
        unit: .count,
        visualRange: .dynamic(padding: 0.15),
        color: .purple
    )

    /// MVRV Ratio
    static let mvrv = MetricConfig(
        id: "market/mvrv",
        name: "MVRV Ratio",
        shortName: "MVRV",
        unit: .ratio,
        visualRange: .dynamic(padding: 0.15),
        color: .orange
    )

    /// Hash Rate
    static let hashRate = MetricConfig(
        id: "mining/hash_rate_mean",
        name: "Hash Rate",
        shortName: "Hash Rate",
        unit: .hashRate,
        visualRange: .dynamic(padding: 0.1),
        color: .green
    )

    /// Supply Last Active 1+ Years Ago
    static let supplyActive1Year = MetricConfig(
        id: "supply/active_more_1y_percent",
        name: "Supply Last Active 1+ Years",
        shortName: "1Y+ Supply",
        unit: .percentage,
        visualRange: .fixed(min: 0, max: 1),
        color: .blue
    )

    /// SOPR (Spent Output Profit Ratio)
    static let sopr = MetricConfig(
        id: "indicators/sopr",
        name: "SOPR",
        shortName: "SOPR",
        unit: .ratio,
        visualRange: .dynamic(padding: 0.15),
        color: .purple
    )

    /// Fear & Greed Index
    static let fearGreed = MetricConfig(
        id: "indicators/fear_greed",
        name: "Fear & Greed Index",
        shortName: "Fear & Greed",
        unit: .percentage,
        visualRange: .fixed(min: 0, max: 1),
        color: .orange
    )

    /// Get metric by ID
    static func metric(withId id: String) -> MetricConfig? {
        allMetrics.first { $0.id == id }
    }
}

// MARK: - Value Formatting

extension MetricConfig {
    /// Format a value according to the metric's unit
    func formatValue(_ value: Double) -> String {
        switch unit.formatStyle {
        case .currency:
            return formatCurrency(value)
        case .percentage:
            return String(format: "%.1f%%", value * 100)
        case .decimal(let places):
            return String(format: "%.\(places)f", value)
        case .integer:
            return formatInteger(value)
        case .hashRate:
            return formatHashRate(value)
        }
    }

    /// Format a change value (for displaying +/- changes)
    func formatChange(_ change: Double) -> String {
        String(format: "%.2f%%", abs(change))
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.2fK", value / 1_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }

    private func formatInteger(_ value: Double) -> String {
        let intValue = Int(value)
        if intValue >= 1_000_000 {
            return String(format: "%.2fM", Double(intValue) / 1_000_000)
        } else if intValue >= 1_000 {
            return String(format: "%.2fK", Double(intValue) / 1_000)
        } else {
            return "\(intValue)"
        }
    }

    private func formatHashRate(_ value: Double) -> String {
        // Value is in H/s, convert to EH/s
        let ehps = value / 1_000_000_000_000_000_000
        return String(format: "%.0f EH/s", ehps)
    }
}
