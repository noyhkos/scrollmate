import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var splashOpacity: Double = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollTabView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            SplashView()
                .opacity(splashOpacity)
                .allowsHitTesting(splashOpacity > 0)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.1)) {
                            splashOpacity = 0
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
