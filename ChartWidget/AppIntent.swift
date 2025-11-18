//
//  AppIntent.swift
//  ChartWidget
//
//  Created by Ondřej Bárta on 15/11/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Configure your Glassnode chart widget." }

    @Parameter(title: "Metric")
    var metricId: MetricEntity?

    init(metricId: MetricEntity) {
        self.metricId = metricId
    }

    init() {
        self.metricId = .supplyInProfit
    }
}

// MARK: - Metric Entity

struct MetricEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Metric"

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = MetricEntityQuery()

    // Predefined metrics
    static let price = MetricEntity(id: "market/price_usd_close", name: "Price")
    static let marketCap = MetricEntity(id: "market/marketcap_usd", name: "Market Cap")
    static let supplyInProfit = MetricEntity(id: "supply/profit_relative", name: "Percent Supply in Profit")
    static let activeAddresses = MetricEntity(id: "addresses/active_count", name: "Active Addresses")
    static let transactionCount = MetricEntity(id: "transactions/count", name: "Transaction Count")
    static let mvrv = MetricEntity(id: "market/mvrv", name: "MVRV Ratio")
    static let hashRate = MetricEntity(id: "mining/hash_rate_mean", name: "Hash Rate")
    static let supplyActive1Year = MetricEntity(id: "supply/active_more_1y_percent", name: "Supply Last Active 1+ Years")
    static let sopr = MetricEntity(id: "indicators/sopr", name: "SOPR")
    static let fearGreed = MetricEntity(id: "indicators/fear_greed", name: "Fear & Greed Index")

    static let allMetrics: [MetricEntity] = [
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
}

// MARK: - Metric Entity Query

struct MetricEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MetricEntity] {
        MetricEntity.allMetrics.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [MetricEntity] {
        MetricEntity.allMetrics
    }

    func defaultResult() async -> MetricEntity? {
        .supplyInProfit
    }
}

