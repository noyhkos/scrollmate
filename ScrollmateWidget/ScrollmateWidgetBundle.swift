import WidgetKit
import SwiftUI

@main
struct ScrollmateWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScrollmateWidget()
        ScrollmateControl()
        ScrollmateLiveActivity()
    }
}
