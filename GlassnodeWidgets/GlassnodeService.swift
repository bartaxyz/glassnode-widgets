//
//  GlassnodeService.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import Foundation

actor GlassnodeService {
    enum APIError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse
        case unauthorized
        case rateLimited
        case http(Int)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Missing API key"
            case .invalidResponse: return "Invalid response"
            case .unauthorized: return "Unauthorized (invalid API key)"
            case .rateLimited: return "Rate limited"
            case .http(let code): return "HTTP error: \(code)"
            case .decoding(let error): return "Decoding error: \(error.localizedDescription)"
            }
        }
    }

    private let baseURL = URL(string: "https://api.glassnode.com")!
    private let session: URLSession
    private let keychain: KeychainClient

    // In-memory cache to avoid repeated Keychain reads
    private var cachedAPIKey: String?

    init(session: URLSession = .shared, keychain: KeychainClient = KeychainClient()) {
        self.session = session
        self.keychain = keychain
    }

    func updateCachedAPIKey(_ key: String?) {
        self.cachedAPIKey = key
    }

    private func getAPIKey() throws -> String {
        if let cachedAPIKey { return cachedAPIKey }
        if let key = try keychain.readAPIKey(), !key.isEmpty {
            self.cachedAPIKey = key
            return key
        }
        throw APIError.missingAPIKey
    }

    // Generic GET that decodes to T
    func get<T: Decodable>(_ path: String,
                           query: [URLQueryItem] = [],
                           as type: T.Type = T.self) async throws -> T {
        let apiKey = try getAPIKey()
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var items = query
        items.append(URLQueryItem(name: "api_key", value: apiKey))
        components.queryItems = items

        guard let url = components.url else { throw APIError.invalidResponse }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            do {
                return try await JSONDecoder.glassnode.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        case 401: throw APIError.unauthorized
        case 429: throw APIError.rateLimited
        default: throw APIError.http(http.statusCode)
        }
    }

    // MARK: - Validation
    func validateAPIKey() async -> Bool {
        do {
            // Attempt a lightweight real endpoint call to validate the key.
            // Using Relative Supply in Profit as a quick check; we only need to confirm authorization.
            _ = try await fetchRelativeSupplyInProfit(asset: "BTC", interval: "24h")
            return true
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError { return false }
            return false
        }
    }
}

// MARK: - JSONDecoder helpers
extension JSONDecoder {
    /// A decoder configured for typical Glassnode time series payloads.
    static var glassnode: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }
}

// MARK: - Models for time series
struct TimeValue: Decodable, Identifiable {
    let t: Date
    let v: Double

    var id: Date { t }
}

// MARK: - Endpoints
enum GlassnodeEndpoint {
    // Placeholder path for Relative Supply in Profit; please adjust to the exact Glassnode path.
    // Example style: "/v1/metrics/indicators/supply_in_profit_relative"
    case relativeSupplyInProfit(asset: String, interval: String)

    var path: String {
        switch self {
        case .relativeSupplyInProfit:
            return "/v1/metrics/indicators/supply_in_profit_relative"
        }
    }

    var defaultQuery: [URLQueryItem] {
        switch self {
        case let .relativeSupplyInProfit(asset, interval):
            return [
                URLQueryItem(name: "a", value: asset),
                URLQueryItem(name: "i", value: interval)
            ]
        }
    }
}

extension GlassnodeService {
    // Typed helper for Relative Supply in Profit
    func fetchRelativeSupplyInProfit(asset: String = "BTC", interval: String = "24h") async throws -> [TimeValue] {
        let endpoint = GlassnodeEndpoint.relativeSupplyInProfit(asset: asset, interval: interval)
        return try await get(endpoint.path, query: endpoint.defaultQuery, as: [TimeValue].self)
    }
}
