import SwiftUI

struct SessionRowView: View {
    let session: ScrollSession

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(Self.timeFormatter.string(from: session.startTime)) - \(Self.timeFormatter.string(from: session.endTime))")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Text(formattedDuration)
                    .font(.system(size: 14))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 0.5)
                .padding(.horizontal, 24)
        }
    }

    private var formattedDuration: String {
        let total = Int(session.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "< 1m"
    }
}
