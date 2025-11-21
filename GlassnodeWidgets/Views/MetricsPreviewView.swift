//
//  MetricsPreviewView.swift
//  GlassnodeWidgets
//
//  Preview all available metrics with live charts
//

import SwiftUI

struct MetricsPreviewView: View {
    @EnvironmentObject var keychainClient: KeychainClient
    @State private var metricsData: [String: [TimeValue]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTimeRange: String = "24h"

    private let allMetrics = MetricConfig.allMetrics

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading metrics...")
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await fetchAllMetrics()
                        }
                    }
                }
                .padding()
            } else {
                ForEach(allMetrics) { metric in
                    if let data = metricsData[metric.id], !data.isEmpty {
                        MetricChartView(
                            data: data,
                            metricId: metric.id,
                            timeRange: selectedTimeRange,
                            showXAxis: true,
                            showYAxis: true,
                            showHeader: true,
                            showDeltaValue: true,
                            height: 200,
                            error: nil
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await fetchAllMetrics()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("Last 24 Hours").tag("24h")
                    Text("Since Midnight").tag("today")
                }
                //.pickerStyle(.segmented)
                .onChange(of: selectedTimeRange) { _ in
                    Task {
                        await fetchAllMetrics()
                    }
                }
            }
        }
        .task {
            await fetchAllMetrics()
        }
    }

    private func fetchAllMetrics() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let apiKey = try keychainClient.readAPIKey(), !apiKey.isEmpty else {
                errorMessage = "No API key configured"
                isLoading = false
                return
            }

            var newData: [String: [TimeValue]] = [:]

            // Fetch all metrics concurrently
            await withTaskGroup(of: (String, Result<[TimeValue], Error>).self) { group in
                for metric in allMetrics {
                    group.addTask {
                        do {
                            let data = try await MetricDataFetcher.fetchMetricData(
                                metricId: metric.id,
                                timeRange: selectedTimeRange,
                                apiKey: apiKey
                            )
                            return (metric.id, .success(data))
                        } catch {
                            return (metric.id, .failure(error))
                        }
                    }
                }

                for await (metricId, result) in group {
                    switch result {
                    case .success(let data):
                        newData[metricId] = data
                    case .failure(let error):
                        print("Error fetching \(metricId): \(error.localizedDescription)")
                    }
                }
            }

            metricsData = newData
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        MetricsPreviewView()
            .environmentObject(KeychainClient())
    }
}
