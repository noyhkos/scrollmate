import SwiftUI

// MARK: - Root View

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab: AppTab = .scroll
    @State private var splashOpacity: Double = 1

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                ScrollTabView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // BottomTabBar hidden until remaining tabs are implemented
                // BottomTabBar(selectedTab: $selectedTab)
            }

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

// MARK: - Bottom Tab Bar

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                        Text(tab.label)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(selectedTab == tab ? .appAccent : Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(
            Group {
                if #available(iOS 26, *) {
                    RoundedRectangle(cornerRadius: 28)
                        .glassEffect(.regular, in: .rect(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color.black.opacity(0.45))
                        )
                } else {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Coming Soon View

struct ComingSoonView: View {
    let tabName: String

    var body: some View {
        VStack(spacing: 12) {
            Text(tabName)
                .font(.system(.title2, design: .serif))
                .foregroundColor(.appTextPrimary)
            Text("Coming soon")
                .font(.subheadline)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
