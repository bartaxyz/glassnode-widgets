//
//  WidgetMetricConfig.swift
//  ChartWidget
//
//  Created by Assistant on 18/11/25.
//

import Foundation
import SwiftUI

/// Simplified metric configuration for widgets
struct WidgetMetricConfig {
    let id: String
    let name: String
    let shortName: String
    let isPercentage: Bool
    let hasFixedRange: Bool
    let minValue: Double
    let maxValue: Double
    let primaryColor: Color
    let secondaryColor: Color

    func formatValue(_ value: Double) -> String {
        if isPercentage {
            return String(format: "%.1f%%", value * 100)
        }

        // Currency formatting
        if id.contains("price") || id.contains("marketcap") {
            return formatCurrency(value)
        }

        // Count formatting
        if id.contains("count") || id.contains("addresses") || id.contains("transactions") {
            return formatInteger(value)
        }

        // Hash rate formatting
        if id.contains("hash_rate") {
            let ehps = value / 1_000_000_000_000_000_000
            return String(format: "%.0f EH/s", ehps)
        }

        // Default decimal formatting for ratios
        return String(format: "%.2f", value)
    }

    func formatChange(_ change: Double) -> String {
        String(format: "%.2f%%", abs(change))
    }

    func calculateRange(for data: [Double]) -> ClosedRange<Double> {
        if hasFixedRange {
            return minValue...maxValue
        }

        guard !data.isEmpty else { return 0...1 }
        let dataMin = data.min() ?? 0
        let dataMax = data.max() ?? 1
        let range = dataMax - dataMin
        let padding = range * 0.15
        return (dataMin - padding)...(dataMax + padding)
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

    static func config(for metricId: String) -> WidgetMetricConfig {
        switch metricId {
        case "market/price_usd_close":
            return WidgetMetricConfig(
                id: metricId,
                name: "Price",
                shortName: "Price",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .orange,
                secondaryColor: .yellow
            )

        case "market/marketcap_usd":
            return WidgetMetricConfig(
                id: metricId,
                name: "Market Cap",
                shortName: "Market Cap",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .blue,
                secondaryColor: .cyan
            )

        case "supply/profit_relative":
            return WidgetMetricConfig(
                id: metricId,
                name: "Percent Supply in Profit",
                shortName: "Supply in Profit",
                isPercentage: true,
                hasFixedRange: true,
                minValue: 0,
                maxValue: 1,
                primaryColor: .green,
                secondaryColor: .mint
            )

        case "addresses/active_count":
            return WidgetMetricConfig(
                id: metricId,
                name: "Active Addresses",
                shortName: "Active Addresses",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .blue,
                secondaryColor: .cyan
            )

        case "transactions/count":
            return WidgetMetricConfig(
                id: metricId,
                name: "Transaction Count",
                shortName: "Transactions",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .purple,
                secondaryColor: .indigo
            )

        case "market/mvrv":
            return WidgetMetricConfig(
                id: metricId,
                name: "MVRV Ratio",
                shortName: "MVRV",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .orange,
                secondaryColor: .yellow
            )

        case "mining/hash_rate_mean":
            return WidgetMetricConfig(
                id: metricId,
                name: "Hash Rate",
                shortName: "Hash Rate",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .green,
                secondaryColor: .mint
            )

        case "supply/active_more_1y_percent":
            return WidgetMetricConfig(
                id: metricId,
                name: "Supply Last Active 1+ Years",
                shortName: "1Y+ Supply",
                isPercentage: true,
                hasFixedRange: true,
                minValue: 0,
                maxValue: 1,
                primaryColor: .blue,
                secondaryColor: .cyan
            )

        case "indicators/sopr":
            return WidgetMetricConfig(
                id: metricId,
                name: "SOPR",
                shortName: "SOPR",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .purple,
                secondaryColor: .indigo
            )

        case "indicators/fear_greed":
            return WidgetMetricConfig(
                id: metricId,
                name: "Fear & Greed Index",
                shortName: "Fear & Greed",
                isPercentage: true,
                hasFixedRange: true,
                minValue: 0,
                maxValue: 1,
                primaryColor: .orange,
                secondaryColor: .yellow
            )

        default:
            // Default configuration
            return WidgetMetricConfig(
                id: metricId,
                name: "BTC Metric",
                shortName: "Metric",
                isPercentage: false,
                hasFixedRange: false,
                minValue: 0,
                maxValue: 1,
                primaryColor: .blue,
                secondaryColor: .cyan
            )
        }
    }
}
