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

                VStack(alignment: .center, spacing: 6) {
                    Text("splash.line1")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundColor(.appTextPrimary)
                    Text("splash.line2")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
}
