//
//  AppIntent.swift
//  QuickToDoWidget
//
//  Created by Bratislav Ljubisic Home  on 7/30/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("This is an example widget.")

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
