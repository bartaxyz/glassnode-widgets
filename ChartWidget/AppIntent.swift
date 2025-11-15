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
}
