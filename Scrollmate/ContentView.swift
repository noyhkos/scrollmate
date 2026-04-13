import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var splashOpacity: Double = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollTabView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if splashOpacity > 0 {
                SplashView()
                    .opacity(splashOpacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                splashOpacity = 0
                            }
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
