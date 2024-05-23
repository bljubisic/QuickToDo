//
//  QuickToDoWidgetLiveActivity.swift
//  QuickToDoWidget
//
//  Created by Bratislav Ljubisic Home  on 7/30/23.
//  Copyright © 2023 Bratislav Ljubisic. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct QuickToDoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct QuickToDoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickToDoWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension QuickToDoWidgetAttributes {
    fileprivate static var preview: QuickToDoWidgetAttributes {
        QuickToDoWidgetAttributes(name: "World")
    }
}

extension QuickToDoWidgetAttributes.ContentState {
    fileprivate static var smiley: QuickToDoWidgetAttributes.ContentState {
        QuickToDoWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: QuickToDoWidgetAttributes.ContentState {
         QuickToDoWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: QuickToDoWidgetAttributes.preview) {
   QuickToDoWidgetLiveActivity()
} contentStates: {
    QuickToDoWidgetAttributes.ContentState.smiley
    QuickToDoWidgetAttributes.ContentState.starEyes
}
