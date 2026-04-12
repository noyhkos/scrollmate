import ActivityKit
import WidgetKit
import SwiftUI

struct ScrollmateLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScrollmateAttributes.self) { context in
            HStack(spacing: 16) {
                Image("CircledLogoLight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

                Text(context.state.startTime, style: .timer)
                    .font(.system(size: 24, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(intent: ToggleTimerIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Stop")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.11, green: 0.56, blue: 1.0))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color.black)
        }
    }
}
