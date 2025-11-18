//
//  ChartWidget.swift
//  ChartWidget
//
//  Created by Ondřej Bárta on 15/11/25.
//

import WidgetKit
import SwiftUI
import Charts

// Lightweight, non-actor based fetcher for widgets to avoid memory leaks
struct WidgetDataFetcher {
    enum FetchError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case httpError(Int)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "No API key configured"
            case .invalidURL: return "Invalid URL"
            case .httpError(let code): return "HTTP error: \(code)"
            case .decodingError: return "Failed to decode response"
            }
        }
    }

    static func fetchData(metricId: String = "supply/profit_relative") async throws -> [TimeValue] {
        // Read API key from keychain
        let keychain = KeychainClient()
        guard let apiKey = try keychain.readAPIKey(), !apiKey.isEmpty else {
            throw FetchError.missingAPIKey
        }

        // Calculate timestamp for 24 hours ago to limit data returned by API
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let sinceTimestamp = String(Int(oneDayAgo.timeIntervalSince1970))

        // Build URL with metric path
        let metricPath = "/v1/metrics/\(metricId)"
        var components = URLComponents(string: "https://api.glassnode.com\(metricPath)")!
        components.queryItems = [
            URLQueryItem(name: "a", value: "BTC"),
            URLQueryItem(name: "i", value: "1h"),
            URLQueryItem(name: "s", value: sinceTimestamp),  // Only fetch last 24h
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components.url else {
            throw FetchError.invalidURL
        }

        // Create minimal session configuration
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20  // Reduced from 30
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Perform request - session will be deallocated immediately after
        let (data, response) = try await URLSession(configuration: config).data(from: url)

        // Check response
        guard let http = response as? HTTPURLResponse else {
            throw FetchError.httpError(0)
        }

        guard http.statusCode == 200 else {
            throw FetchError.httpError(http.statusCode)
        }

        // Decode - only 24 data points
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        guard let result = try? decoder.decode([TimeValue].self, from: data) else {
            throw FetchError.decodingError
        }

        // Limit to maximum 24 points to ensure we don't exceed memory
        let limitedResult = Array(result.suffix(24))

        return limitedResult
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), metricId: "supply/profit_relative", data: Self.placeholderData, error: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // For snapshots, return placeholder data quickly
        let metricId = configuration.metricId?.id ?? "supply/profit_relative"
        return SimpleEntry(date: Date(), metricId: metricId, data: Self.placeholderData, error: nil)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let metricId = configuration.metricId?.id ?? "supply/profit_relative"

        do {
            // Use lightweight fetcher that doesn't create actors or retain sessions
            // Data is already filtered to last 24h by the API, no need to filter again
            let data = try await WidgetDataFetcher.fetchData(metricId: metricId)

            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: data, error: nil)

            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch WidgetDataFetcher.FetchError.missingAPIKey {
            // No API key configured
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: "No API key configured. Please open the app and enter your Glassnode API key.")
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch WidgetDataFetcher.FetchError.httpError(401) {
            // Invalid API key
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: "Invalid API key. Please check your key in the app.")
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))

        } catch {
            // Other errors
            let errorMsg = "Error: \(error.localizedDescription)"
            let entry = SimpleEntry(date: currentDate, metricId: metricId, data: [], error: errorMsg)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        }
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
}

struct ChartWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let error = entry.error {
            ErrorView(error: error)
        } else if entry.data.isEmpty {
            EmptyView()
        } else {
            // Use different views for lock screen vs home screen
            switch family {
            case .accessoryCircular:
                LockScreenCircularView(data: entry.data, metricId: entry.metricId)
            case .accessoryRectangular:
                LockScreenRectangularView(data: entry.data, metricId: entry.metricId)
            case .accessoryInline:
                LockScreenInlineView(data: entry.data, metricId: entry.metricId)
            default:
                ChartView(data: entry.data, metricId: entry.metricId, family: family)
            }
        }
    }
}

struct ChartView: View {
    let data: [TimeValue]
    let metricId: String
    let family: WidgetFamily
    let asset: String = "BTC"  // Default to BTC for now

    private var metricConfig: WidgetMetricConfig {
        WidgetMetricConfig.config(for: metricId)
    }

    private var currentValue: Double {
        data.first?.v ?? 0
    }

    private var percentChange: Double {
        guard let first = data.first?.v, let last = data.last?.v, last > 0 else { return 0 }
        return ((first - last) / last) * 100
    }

    private var isPositive: Bool {
        percentChange >= 0
    }

    // Metric-specific colors
    private var assetColors: (primary: Color, secondary: Color) {
        (metricConfig.primaryColor, metricConfig.secondaryColor)
    }

    // Calculate chart Y domain with padding
    private var chartYDomain: ClosedRange<Double> {
        let values = data.map { $0.v }
        return metricConfig.calculateRange(for: values)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("BTC: \(metricConfig.shortName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("24h")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Current value & change
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metricConfig.formatValue(currentValue))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)

                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(metricConfig.formatChange(percentChange))
                        .font(.caption)
                }
                .foregroundStyle(isPositive ? .green : .red)
            }

            // Chart - restored with gradient and smoothing
            let sortedData = data.sorted(by: { $0.t < $1.t })

            Chart {
                // Guide lines for percentage-based metrics (supply in profit, 1Y+ supply, fear & greed)
                if metricConfig.isPercentage {
                    if chartYDomain.contains(0.5) {
                        RuleMark(y: .value("Bottom", 0.5))
                            .foregroundStyle(.green.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    if chartYDomain.contains(0.95) {
                        RuleMark(y: .value("Top", 0.95))
                            .foregroundStyle(.red.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }

                // Add a neutral line at 1.0 for SOPR (spent output profit ratio)
                if metricId == "indicators/sopr" && chartYDomain.contains(1.0) {
                    RuleMark(y: .value("Break-even", 1.0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                // Data visualization
                ForEach(sortedData) { item in
                    // Area gradient - fill from line to bottom of chart domain
                    AreaMark(
                        x: .value("Time", item.t),
                        yStart: .value("Baseline", chartYDomain.lowerBound),
                        yEnd: .value("Value", item.v)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: assetColors.primary.opacity(0.4), location: 0),
                                .init(color: assetColors.primary.opacity(0), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Solid color line
                    LineMark(
                        x: .value("Time", item.t),
                        y: .value("Value", item.v)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(assetColors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: .hour, count: 12)) { _ in
                    AxisGridLine()
                        .foregroundStyle(.clear)  // Explicitly clear the grid line
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisValueLabel(format: .dateTime.hour(), centered: true)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(.tertiary.opacity(0.3))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(metricConfig.formatValue(doubleValue))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: chartYDomain)
        }
    }
}

// Lock Screen Widgets
struct LockScreenCircularView: View {
    let data: [TimeValue]
    let metricId: String

    private var metricConfig: WidgetMetricConfig {
        WidgetMetricConfig.config(for: metricId)
    }

    private var currentValue: Double {
        data.first?.v ?? 0
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Text(formatValueCompact(currentValue))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                Text(metricConfig.shortName)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func formatValueCompact(_ value: Double) -> String {
        if metricConfig.isPercentage {
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
    let asset: String = "BTC"  // Default to BTC for now

    private var metricConfig: WidgetMetricConfig {
        WidgetMetricConfig.config(for: metricId)
    }

    private var currentValue: Double {
        data.first?.v ?? 0
    }

    private var percentChange: Double {
        guard let first = data.first?.v, let last = data.last?.v, last > 0 else { return 0 }
        return ((first - last) / last) * 100
    }

    private var isPositive: Bool {
        percentChange >= 0
    }

    // Metric-specific colors
    private var assetColors: (primary: Color, secondary: Color) {
        (metricConfig.primaryColor, metricConfig.secondaryColor)
    }

    // Calculate chart Y domain with padding to zoom into data range
    private var chartYDomain: ClosedRange<Double> {
        let values = data.map { $0.v }
        return metricConfig.calculateRange(for: values)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title
            Text("\(asset): \(metricConfig.formatValue(currentValue)) \(metricConfig.shortName)")
                .font(.body)
                .fontWeight(.semibold)
                .lineLimit(1)

            // Delta
            /*
             HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 8))
                Text(String(format: "%.2f%%", abs(percentChange)))
                    .font(.system(size: 10))
            }
            .foregroundStyle(isPositive ? .green : .red)
             */

            // Chart with gradient
            let sortedData = data.sorted(by: { $0.t < $1.t })
            Chart(sortedData) { item in
                // Area gradient
                AreaMark(
                    x: .value("Time", item.t),
                    yStart: .value("Baseline", chartYDomain.lowerBound),
                    yEnd: .value("Value", item.v)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: assetColors.primary.opacity(0.4), location: 0),
                            .init(color: assetColors.primary.opacity(0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                LineMark(
                    x: .value("Time", item.t),
                    y: .value("Value", item.v)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(assetColors.primary)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: chartYDomain)
            .frame(height: 30)
        }
    }
}

struct LockScreenInlineView: View {
    let data: [TimeValue]
    let metricId: String

    private var metricConfig: WidgetMetricConfig {
        WidgetMetricConfig.config(for: metricId)
    }

    private var currentValue: Double {
        data.first?.v ?? 0
    }

    var body: some View {
        Text("BTC: \(metricConfig.formatValue(currentValue)) \(metricConfig.shortName)")
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

#Preview(as: .systemSmall) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}

#Preview(as: .systemMedium) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}

#Preview(as: .systemLarge) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}

#Preview(as: .systemExtraLarge) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}

#Preview(as: .accessoryCircular) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}

#Preview(as: .accessoryRectangular) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}

#Preview(as: .accessoryInline) {
    ChartWidget()
} timeline: {
    SimpleEntry(date: .now, metricId: "supply/profit_relative", data: Provider.placeholderData, error: nil)
}
