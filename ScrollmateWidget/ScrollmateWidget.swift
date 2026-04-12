import WidgetKit
import SwiftUI
import AppIntents

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let startTime: Date?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), isActive: false, startTime: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let start = SharedStorage.shared.activeTimers["scrollmate"]
        completion(SimpleEntry(date: Date(), isActive: start != nil, startTime: start))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let start = SharedStorage.shared.activeTimers["scrollmate"]
        let entry = SimpleEntry(date: Date(), isActive: start != nil, startTime: start)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct ScrollmateWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Let's Scroll!")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
//                .padding(.bottom, )

            Spacer()

            // Elapsed timer — Text(.timer) auto-counts without per-second timeline updates
            if entry.isActive, let start = entry.startTime {
                Text(start, style: .timer)
                    .font(.system(size: 24, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            } else {
                Text("00:00:00")
                    .font(.system(size: 24, weight: .thin, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Toggle button — crown when active (matches app), play when inactive
            Button(intent: ToggleTimerIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: entry.isActive ? "crown.fill" : "play.fill")
                        .font(.system(size: 15, weight: .medium))
                    Text(entry.isActive ? "Stop" : "Start")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(entry.isActive ? Color(red: 0.11, green: 0.56, blue: 1.0) : Color.green)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .containerBackground(colorScheme == .dark ? Color.black : Color.white, for: .widget)
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
