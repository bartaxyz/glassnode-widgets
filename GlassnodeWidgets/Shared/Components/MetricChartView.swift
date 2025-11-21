//
//  MetricChartView.swift
//  GlassnodeWidgets
//
//  Reusable chart component for displaying metric data
//

import SwiftUI
import Charts

/// Reusable metric chart view
struct MetricChartView: View {
    let data: [TimeValue]
    let metricId: String
    let timeRange: String
    let showXAxis: Bool
    let showYAxis: Bool
    let showHeader: Bool
    let showDeltaValue: Bool
    let height: CGFloat?
    let error: String?

    private var metricConfig: MetricConfig? {
        MetricConfig.metric(withId: metricId)
    }

    private var hasData: Bool {
        !data.isEmpty
    }

    private var currentValue: Double? {
        data.last?.v
    }

    // Absolute delta (value difference from oldest to newest)
    private var deltaValue: Double {
        guard let first = data.first?.v, let last = data.last?.v else { return 0 }
        return last - first
    }

    // Relative delta (percentage change from oldest to newest)
    private var percentChange: Double {
        guard let first = data.first?.v, let last = data.last?.v, first > 0 else { return 0 }
        return ((last - first) / first) * 100
    }

    private var isPositive: Bool {
        deltaValue >= 0
    }

    // Formatted delta display based on config
    private var deltaDisplayText: String {
        guard hasData else { return emptyDeltaValue }

        guard let config = metricConfig else {
            return String(format: "%.2f%%", abs(percentChange))
        }

        switch config.deltaDisplayMode {
        case .absolute:
            return config.formatValue(abs(deltaValue))
        case .relative:
            return config.formatChange(percentChange)
        }
    }

    // Format empty values based on unit type
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

    private var emptyDeltaValue: String {
        guard let config = metricConfig else { return "-%" }
        switch config.deltaDisplayMode {
        case .absolute:
            return emptyValue
        case .relative:
            return "-%"
        }
    }

    private func formattedValue(_ value: Double?) -> String {
        guard let value = value else { return emptyValue }
        return metricConfig?.formatValue(value) ?? String(format: "%.2f", value)
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = data.map { $0.v }
        guard let config = metricConfig else {
            guard !values.isEmpty else { return 0...1 }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = maxValue - minValue
            let padding = range * 0.15
            return (minValue - padding)...(maxValue + padding)
        }
        return config.visualRange.calculateRange(for: values)
    }

    private var todayXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return startOfDay...endOfDay
    }

    private var timeRangeLabel: String {
        timeRange == "today" ? "Today" : "24h"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showHeader {
                // Header
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("BTC: \(metricConfig?.shortName ?? "Metric")")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .opacity(0.5)
                }
            }

            if showDeltaValue {
                // Compact view: Current value with delta on the side
                HStack(spacing: 2) {
                    Text(formattedValue(currentValue))
                        .font(.body)
                        .fontWeight(.semibold)
                    Spacer()
                    if hasData {
                        Image(systemName: isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .opacity(0.5)
                            .font(.system(size: 8))
                    }
                    Text(deltaDisplayText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .opacity(0.5)
                }
            }

            // Chart or error message
            if let error = error {
                // Show error message instead of empty chart
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: height)
            } else {
                let sortedData = data.sorted(by: { $0.t < $1.t })
                let color = AssetConfig.defaultAsset.color

                Chart {
                // Baseline at starting value
                if let startingValue = sortedData.first?.v {
                    RuleMark(y: .value("Baseline", startingValue))
                        .foregroundStyle(.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                // Add a neutral line at 1.0 for SOPR (spent output profit ratio)
                if metricId == "indicators/sopr" && chartYDomain.contains(1.0) {
                    RuleMark(y: .value("Break-even", 1.0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                // Data visualization
                ForEach(sortedData) { item in
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
                                .init(color: color.opacity(0.4), location: 0),
                                .init(color: color.opacity(0), location: 1.0)
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
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }
            .if(showXAxis) { view in
                view.chartXAxis {
                    AxisMarks(position: .bottom, values: .stride(by: .hour, count: 12)) { _ in
                        AxisGridLine()
                            .foregroundStyle(.clear)
                        AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.tertiary)
                        AxisValueLabel(format: .dateTime.hour(), centered: true)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .if(showYAxis) { view in
                view.chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(.tertiary.opacity(0.3))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(metricConfig?.formatValue(doubleValue) ?? String(format: "%.2f", doubleValue))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .if(!showXAxis) { view in
                view.chartXAxis(.hidden)
            }
            .if(!showYAxis) { view in
                view.chartYAxis(.hidden)
            }
            .chartYScale(domain: chartYDomain)
            .modifier(XScaleModifier(timeRange: timeRange, domain: todayXDomain))
            .if(height != nil) { view in
                view.frame(height: height)
            }
            }
        }
    }
}

// Conditional X-scale modifier
struct XScaleModifier: ViewModifier {
    let timeRange: String
    let domain: ClosedRange<Date>

    func body(content: Content) -> some View {
        if timeRange == "today" {
            content.chartXScale(domain: domain)
        } else {
            content
        }
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
