//
//  TimeValue.swift
//  GlassnodeWidgets
//
//  Shared model for time-series data
//

import Foundation

/// Time-series data point with timestamp and value
struct TimeValue: Codable, Identifiable, Sendable {
    let t: Date
    let v: Double

    var id: Date { t }
}
