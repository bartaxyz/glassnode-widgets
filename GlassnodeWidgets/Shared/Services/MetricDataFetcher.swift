//
//  MetricDataFetcher.swift
//  GlassnodeWidgets
//
//  Unified data fetching for metrics across widget and main app
//

import Foundation

/// Unified metric data fetcher
struct MetricDataFetcher {
    enum FetchError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case httpError(Int, message: String? = nil)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "No API key configured"
            case .invalidURL: return "Invalid URL"
            case .httpError(let code, let message):
                if let message = message {
                    return "Error \(code): \(message)"
                }
                return "HTTP error: \(code)"
            case .decodingError: return "Failed to decode response"
            }
        }
    }

    // Structure to decode API error responses
    private struct APIErrorResponse: Decodable {
        let error: String?
        let message: String?

        var errorMessage: String? {
            error ?? message
        }
    }

    /// Fetch metric data with unified logic
    /// - Parameters:
    ///   - metricId: The metric ID (e.g., "market/price_usd_close")
    ///   - timeRange: "24h" for last 24 hours, "today" for since midnight
    ///   - apiKey: Glassnode API key
    /// - Returns: Array of TimeValue data points
    static func fetchMetricData(
        metricId: String,
        timeRange: String = "24h",
        apiKey: String
    ) async throws -> [TimeValue] {
        // Get interval from metric config
        let interval = MetricConfig.metric(withId: metricId)?.interval ?? "1h"

        // Always fetch last 24 hours
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let sinceTimestamp = String(Int(oneDayAgo.timeIntervalSince1970))

        // Build URL with metric path
        let metricPath = "/v1/metrics/\(metricId)"
        var components = URLComponents(string: "https://api.glassnode.com\(metricPath)")!
        components.queryItems = [
            URLQueryItem(name: "a", value: "BTC"),
            URLQueryItem(name: "i", value: interval),
            URLQueryItem(name: "s", value: sinceTimestamp),
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components.url else {
            throw FetchError.invalidURL
        }

        // Setup UserDefaults caching with App Group
        let cacheKey = "metric_\(metricId)_\(timeRange)"
        let sharedDefaults = UserDefaults(suiteName: "group.com.ondrejbarta.GlassnodeWidgets")

        // Create minimal session configuration optimized for widgets
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10  // Reduced from 20s
        config.timeoutIntervalForResource = 15  // Overall timeout
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        // Create request with better configuration
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.networkServiceType = .responsiveData  // Better priority for widgets

        // Create session once and reuse for all attempts
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }

        var lastError: Error?
        let maxAttempts = 2  // Reduced from 3

        for attempt in 1...maxAttempts {
            do {
                // Perform request
                let (data, response) = try await session.data(for: request)

                // Check response
                guard let http = response as? HTTPURLResponse else {
                    throw FetchError.httpError(0)
                }

                // Handle client errors immediately (don't retry)
                if (400...499).contains(http.statusCode) {
                    let errorMessage = extractErrorMessage(from: data)
                    throw FetchError.httpError(http.statusCode, message: errorMessage)
                }

                // Check for success
                if http.statusCode == 200 {
                    // Decode
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970

                    guard let result = try? decoder.decode([TimeValue].self, from: data) else {
                        throw FetchError.decodingError
                    }

                    // Filter based on time range
                    let filteredResult: [TimeValue]
                    if timeRange == "today" {
                        // Get midnight of current day in local timezone, minus 30 minute margin
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: Date())
                        let todayWithMargin = today.addingTimeInterval(-30 * 60)  // 30 minutes before midnight
                        // Filter to include data points from 30 minutes before midnight onwards
                        filteredResult = result.filter { $0.t >= todayWithMargin }
                    } else {
                        // Use all 24h data
                        filteredResult = result
                    }

                    // Limit based on interval to ensure we don't exceed memory
                    // 10m interval: max 144 points (24h), 1h interval: max 24 points (24h)
                    let maxPoints = interval == "10m" ? 144 : 24
                    let limitedResult = Array(filteredResult.suffix(maxPoints))

                    // Cache successful response
                    if let encoded = try? JSONEncoder().encode(limitedResult) {
                        sharedDefaults?.set(encoded, forKey: cacheKey)
                        sharedDefaults?.set(Date(), forKey: "\(cacheKey)_timestamp")
                    }

                    return limitedResult
                }

                // Handle HTTP errors
                if (500...599).contains(http.statusCode) {
                    // Server error, retryable
                    let errorMessage = extractErrorMessage(from: data)
                    throw FetchError.httpError(http.statusCode, message: errorMessage)
                } else {
                    // Other error
                    let errorMessage = extractErrorMessage(from: data)
                    throw FetchError.httpError(http.statusCode, message: errorMessage)
                }

            } catch {
                lastError = error

                // Determine if we should retry
                let isRetryable: Bool
                if let fetchError = error as? FetchError {
                    switch fetchError {
                    case .httpError(let code, _):
                        // Don't retry client errors (4xx)
                        isRetryable = (500...599).contains(code) || code == 0 // 0 usually means network error
                    case .missingAPIKey, .invalidURL, .decodingError:
                        isRetryable = false
                    }
                } else {
                    // URLSession errors (network dropped, etc) are usually retryable
                    isRetryable = true
                }

                if !isRetryable || attempt == maxAttempts {
                    // Failed all attempts, try to return cached data
                    if let cachedData = sharedDefaults?.data(forKey: cacheKey),
                       let cached = try? JSONDecoder().decode([TimeValue].self, from: cachedData) {
                        // Return cached data instead of throwing
                        return cached
                    }
                    throw error
                }

                // Wait before retrying - shorter delay for widgets
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds (reduced from 1s)
            }
        }

        // Final fallback to cache
        if let cachedData = sharedDefaults?.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([TimeValue].self, from: cachedData) {
            return cached
        }

        throw lastError ?? FetchError.httpError(0)
    }

    // Helper to extract error message from API response
    private static func extractErrorMessage(from data: Data) -> String? {
        guard let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
              let message = errorResponse.errorMessage else {
            // Try to parse as plain text if JSON decoding fails
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                // Truncate to reasonable length
                return text.count > 100 ? String(text.prefix(100)) : text
            }
            return nil
        }
        return message
    }
}
