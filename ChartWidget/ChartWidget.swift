//
//  ChartWidget.swift
//  ChartWidget
//
//  Created by Ondřej Bárta on 15/11/25.
//

import WidgetKit
import SwiftUI
import Charts

// Widget-specific wrapper for MetricDataFetcher
struct WidgetDataFetcher {
    static func fetchData(metricId: String = "supply/profit_relative", timeRange: String = "24h") async throws -> [TimeValue] {
        // Read API key from keychain
        let keychain = KeychainClient()

        // readAPIKey() will:
        // - Return nil if no key is configured
        // - Throw KeychainError.interactionNotAllowed if device is locked (error -25308)
        // - Return the key if successful
        guard let apiKey = try keychain.readAPIKey(), !apiKey.isEmpty else {
            throw MetricDataFetcher.FetchError.missingAPIKey
        }

        // Use shared fetcher
        return try await MetricDataFetcher.fetchMetricData(
            metricId: metricId,
            timeRange: timeRange,
            apiKey: apiKey
        )
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), metricId: "supply/profit_relative", data: Self.placeholderData, error: nil, timeRange: "24h")
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // For snapshots, return placeholder data quickly
        let metricId = configuration.metricId?.id ?? "supply/profit_relative"
        let timeRange = configuration.timeRange?.id ?? "24h"
        return SimpleEntry(date: Date(), metricId: metricId, data: Self.placeholderData, error: nil, timeRange: timeRange)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let metricId = configuration.metricId?.id ?? "supply/profit_relative"
        let timeRange = configuration.timeRange?.id ?? "24h"

        do {
            // Use lightweight fetcher that doesn't create actors or retain sessions
            let data = try await WidgetDataFetcher.fetchData(metricId: metricId, timeRange: timeRange)

            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: data, error: nil, timeRange: timeRange)

            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch KeychainClient.KeychainError.interactionNotAllowed {
            // Device is locked and keychain can't be accessed (error -25308)
            // This should be temporary - retry sooner
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: "Device locked\nUnlock to update", timeRange: timeRange)
            // Retry after 2 minutes when device might be unlocked
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch MetricDataFetcher.FetchError.missingAPIKey {
            // No API key configured
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: "API key missing\nOpen app to add key", timeRange: timeRange)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch MetricDataFetcher.FetchError.httpError(let statusCode, let message) {
            // HTTP errors with descriptive messages
            let errorMsg: String
            if let message = message, !message.isEmpty {
                // Use API error message if available (truncate if too long)
                errorMsg = message.count > 60 ? String(message.prefix(57)) + "..." : message
            } else {
                // Fallback to generic messages
                switch statusCode {
                case 401:
                    errorMsg = "Invalid API key\nCheck key in app"
                case 429:
                    errorMsg = "Rate limited\nTry again later"
                case 400..<500:
                    errorMsg = "Invalid request\nError \(statusCode)"
                case 500..<600:
                    errorMsg = "Server error\nTry again later"
                default:
                    errorMsg = "Network error\nCheck connection"
                }
            }
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: errorMsg, timeRange: timeRange)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch MetricDataFetcher.FetchError.decodingError {
            // Decoding error
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: "Data format error\nCheck metric config", timeRange: timeRange)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch {
            // Other errors - try to extract useful message
            let errorMsg = formatErrorMessage(error)
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: errorMsg, timeRange: timeRange)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
    }

    // Format error messages to be more readable
    private func formatErrorMessage(_ error: Error) -> String {
        let description = error.localizedDescription
        // Truncate long messages to fit widget
        if description.count > 60 {
            let truncated = description.prefix(57)
            return "\(truncated)..."
        }
        return description
    }

    // Placeholder data for previews (lightweight - only 10 data points)
    static var placeholderData: [TimeValue] {
        let now = Date()
        var data: [TimeValue] = []
        for i in 0..<10 {
            let hours: Double = 2.4
            let seconds: Double = 60 * 60
            let multiplier = Double(i) * hours * seconds
            let offset = -multiplier
            let date = now.addingTimeInterval(offset)

            let divisor: Double = 2.0
            let sinInput = Double(i) / divisor
            let sinValue = sin(sinInput)
            let value = 0.55 + (0.05 * sinValue)

            data.append(TimeValue(t: date, v: value))
        }
        return data
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let metricId: String
    let data: [TimeValue]
    let error: String?
    let timeRange: String
}

struct ChartWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    private var timeRangeLabel: String {
        entry.timeRange == "today" ? "Today" : "24h"
    }

    var body: some View {
        // Use different views for lock screen vs home screen
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(data: entry.data, metricId: entry.metricId, error: entry.error)
        case .accessoryRectangular:
            LockScreenRectangularView(data: entry.data, metricId: entry.metricId, timeRange: entry.timeRange, error: entry.error)
        case .accessoryInline:
            LockScreenInlineView(data: entry.data, metricId: entry.metricId, error: entry.error)
        default:
            ChartView(data: entry.data, metricId: entry.metricId, family: family, timeRangeLabel: timeRangeLabel, timeRange: entry.timeRange, error: entry.error)
        }
    }
}

struct ChartView: View {
    let data: [TimeValue]
    let metricId: String
    let family: WidgetFamily
    let timeRangeLabel: String
    let timeRange: String
    let error: String?

    var body: some View {
        MetricChartView(
            data: data,
            metricId: metricId,
            timeRange: timeRange,
            showXAxis: true,
            showYAxis: true,
            showHeader: true,
            showDeltaValue: false,
            height: nil,
            error: error
        )
    }
}

// Lock Screen Widgets
struct LockScreenCircularView: View {
    let data: [TimeValue]
    let metricId: String
    let error: String?

    private var metricConfig: MetricConfig? {
        MetricConfig.metric(withId: metricId)
    }

    private var currentValue: Double {
        data.last?.v ?? 0
    }

    private var hasData: Bool {
        !data.isEmpty && error == nil
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                if hasData {
                    Text(formatValueCompact(currentValue))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                } else {
                    Text(emptyValueCompact)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                }
                Text(metricConfig?.shortName ?? "Metric")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var emptyValueCompact: String {
        guard let config = metricConfig else { return "-" }
        switch config.unit {
        case .usd: return "$-"
        case .percentage: return "-%"
        case .ratio: return "-"
        case .count: return "-"
        case .hashRate: return "-"
        case .btc: return "-"
        }
    }

    private func formatValueCompact(_ value: Double) -> String {
        if metricConfig?.unit == .percentage {
            return "\(Int(value * 100))%"
        }
        if metricId.contains("price") {
            if value >= 1_000_000 {
                return String(format: "$%.1fM", value / 1_000_000)
            } else if value >= 1_000 {
                return String(format: "$%.1fK", value / 1_000)
            }
            return String(format: "$%.0f", value)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.1f", value)
    }
}

struct LockScreenRectangularView: View {
    let data: [TimeValue]
    let metricId: String
    let timeRange: String
    let error: String?

    var body: some View {
        MetricChartView(
            data: data,
            metricId: metricId,
            timeRange: timeRange,
            showXAxis: false,
            showYAxis: false,
            showHeader: true,
            showDeltaValue: true,
            height: 30,
            error: error
        )
    }
}

struct LockScreenInlineView: View {
    let data: [TimeValue]
    let metricId: String
    let error: String?

    private var metricConfig: MetricConfig? {
        MetricConfig.metric(withId: metricId)
    }

    private var currentValue: Double {
        data.last?.v ?? 0
    }

    private var hasData: Bool {
        !data.isEmpty && error == nil
    }

    private var emptyValue: String {
        guard let config = metricConfig else { return "-" }
        switch config.unit {
        case .usd: return "$-"
        case .percentage: return "-%"
        case .ratio: return "-"
        case .count: return "-"
        case .hashRate: return "-"
        case .btc: return "- BTC"
        }
    }

    var body: some View {
        if hasData {
            Text("BTC: \(metricConfig?.formatValue(currentValue) ?? String(format: "%.2f", currentValue)) \(metricConfig?.shortName ?? "Metric")")
        } else {
            Text("BTC: \(emptyValue) \(metricConfig?.shortName ?? "Metric")")
        }
    }
}

struct ErrorView: View {
    let error: String
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            if family == .systemMedium {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Unable to load")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct ChartWidget: Widget {
    let kind: String = "ChartWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            ChartWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Glassnode Metrics")
        .description("Track Bitcoin metrics from Glassnode over the last 24 hours.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

#Preview("Small Widget", as: .systemSmall) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Medium Widget", as: .systemMedium) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Large Widget", as: .systemLarge) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Extra Large Widget", as: .systemExtraLarge) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Circular Lock Screen", as: .accessoryCircular) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Rectangular Lock Screen", as: .accessoryRectangular) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Inline Lock Screen", as: .accessoryInline) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil, timeRange: "24h")
}

#Preview("Error State", as: .systemMedium) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: [], error: "API key missing\nOpen app to add key", timeRange: "24h")
}

