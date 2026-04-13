import SwiftUI

struct HowToView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("howto.title")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundColor(.appTextPrimary)
                        Text("howto.subtitle")
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundColor(.appTextSecondary)
                    }
                    .padding(.top, 16)

                    // Steps
                    VStack(alignment: .leading, spacing: 28) {
                        HowToStep(number: "1", title: "howto.step1.title", description: "howto.step1.body")
                        HowToStep(number: "2", title: "howto.step2.title", description: "howto.step2.body")
                        HowToStep(number: "3", title: "howto.step3.title", description: "howto.step3.body")
                        HowToStep(number: "4", title: "howto.step4.title", description: "howto.step4.body")
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(height: 1)

                    // Access points
                    VStack(alignment: .leading, spacing: 8) {
                        Text("howto.access.title")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundColor(.appTextPrimary)
                        Text("howto.access.subtitle")
                            .font(.system(size: 15))
                            .foregroundColor(.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        HowToAccess(icon: "iphone",            title: "howto.access.app.title",     description: "howto.access.app.body")
                        HowToAccess(icon: "square.grid.2x2",   title: "howto.access.widget.title",  description: "howto.access.widget.body")
                        HowToAccess(icon: "slider.horizontal.3", title: "howto.access.control.title", description: "howto.access.control.body")
                        HowToAccess(icon: "lock",              title: "howto.access.lock.title",    description: "howto.access.lock.body")
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.appTextSecondary)
                    .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct HowToStep: View {
    let number: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundColor(.appAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct HowToAccess: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(.appAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appTextPrimary)
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
