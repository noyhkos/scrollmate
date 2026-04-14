import WidgetKit
import SwiftUI
import AppIntents

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(hex, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

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
        let start = SharedStorage.shared.activeTimers[scrollmateTimerKey]
        completion(SimpleEntry(date: Date(), isActive: start != nil, startTime: start))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let start = SharedStorage.shared.activeTimers[scrollmateTimerKey]
        let entry = SimpleEntry(date: Date(), isActive: start != nil, startTime: start)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct ScrollmateWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            lockScreenView
        case .accessoryRectangular:
            lockScreenRectView
        default:
            homeScreenView
        }
    }

    // MARK: Lock Screen — circular toggle matching control center style

    private var lockScreenView: some View {
        Button(intent: ToggleTimerIntent()) {
            Image(systemName: entry.isActive ? "stop.fill" : "play.fill")
                .font(.system(size: 20, weight: .medium))
        }
        .containerBackground(.clear, for: .widget)
    }

    // MARK: Lock Screen — rectangular

    private var lockScreenRectView: some View {
        Button(intent: ToggleTimerIntent()) {
            HStack(spacing: 10) {
                Image(systemName: entry.isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .medium))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Scrollmate")
                        .font(.system(size: 13, weight: .semibold))
                    Text(entry.isActive ? "widget.stop" : "widget.start")
                        .font(.system(size: 11, weight: .regular))
                }
                Spacer()
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    // MARK: Home Screen

    private var homeScreenView: some View {
        VStack(spacing: 0) {
            // Header
            Text("widget.title")
                .font(.system(size: 20, weight: .bold, design: .serif))
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
                    Text(entry.isActive ? "widget.stop" : "widget.start")
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
        .padding(4)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(hex: "#111111"), Color(hex: "#1c1c1c")]
                    : [Color(hex: "#f8f8f8"), Color(hex: "#e4e4e4")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct ScrollmateWidget: Widget {
    let kind: String = "ScrollmateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScrollmateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Scrollmate")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
