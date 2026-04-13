import SwiftUI

struct IntervalPickerSheet: View {
    @Binding var pendingInterval: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("common.cancel") { onCancel() }
                    .foregroundColor(.appTextSecondary)
                    .font(.system(size: 16))

                Spacer()

                Button("common.confirm") { onConfirm() }
                    .foregroundColor(.appAccent)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Picker("", selection: $pendingInterval) {
                ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { minute in
                    Text(verbatim: "\(minute) \(String(localized: "unit.min"))")
                        .foregroundColor(.appTextPrimary)
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appSurface)
    }
}
