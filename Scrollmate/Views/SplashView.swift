import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("CircledLogoLight")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Hello,")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundColor(.appTextPrimary)
                    Text("It's a wonderful day, init?")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
}
