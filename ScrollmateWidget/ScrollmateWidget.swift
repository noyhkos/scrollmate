import WidgetKit
import SwiftUI
import AppIntents

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), isActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), isActive: !SharedStorage.shared.activeTimers.isEmpty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), isActive: !SharedStorage.shared.activeTimers.isEmpty)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct ScrollmateWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Button(intent: ToggleTimerIntent()) {
            ZStack {
                Circle()
                    .fill(entry.isActive ? Color.red : Color.green)
                    .frame(width: 64, height: 64)
                Image(systemName: entry.isActive ? "stop.fill" : "play.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.black, for: .widget)
    }
}

struct ScrollmateWidget: Widget {
    let kind: String = "ScrollmateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScrollmateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Scrollmate")
        .description("알림을 시작하거나 종료합니다.")
        .supportedFamilies([.systemSmall])
    }
}
