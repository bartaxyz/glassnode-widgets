//
//  Environment+GlassnodeService.swift
//  GlassnodeWidgets
//
//  Created by Assistant on 15/11/25.
//

import SwiftUI

private struct GlassnodeServiceKey: EnvironmentKey {
    static let defaultValue: GlassnodeService = GlassnodeService()
}

extension EnvironmentValues {
    var glassnodeService: GlassnodeService {
        get { self[GlassnodeServiceKey.self] }
        set { self[GlassnodeServiceKey.self] = newValue }
    }
}

extension View {
    func glassnodeService(_ service: GlassnodeService) -> some View {
        environment(\.glassnodeService, service)
    }
}

private extension EnvironmentValues {
    // Helper to allow injection with a custom modifier without shadowing public API
    var _glassnodeService: GlassnodeService {
        get { self[GlassnodeServiceKey.self] }
        set { self[GlassnodeServiceKey.self] = newValue }
    }
}
