//
//  ScrollmateWidgetLiveActivity.swift
//  ScrollmateWidget
//
//  Created by 김석현 on 2/11/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ScrollmateWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ScrollmateWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScrollmateWidgetAttributes.self) { context in
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

extension ScrollmateWidgetAttributes {
    fileprivate static var preview: ScrollmateWidgetAttributes {
        ScrollmateWidgetAttributes(name: "World")
    }
}

extension ScrollmateWidgetAttributes.ContentState {
    fileprivate static var smiley: ScrollmateWidgetAttributes.ContentState {
        ScrollmateWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ScrollmateWidgetAttributes.ContentState {
         ScrollmateWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ScrollmateWidgetAttributes.preview) {
   ScrollmateWidgetLiveActivity()
} contentStates: {
    ScrollmateWidgetAttributes.ContentState.smiley
    ScrollmateWidgetAttributes.ContentState.starEyes
}
