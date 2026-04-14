import SwiftUI
import Combine

// MARK: - Scroll Tab

struct ScrollTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    private let notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // .default mode yields during touch tracking — avoids blocking user input
    private let ticker = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    @State private var elapsedSeconds: Int = 0
    @State private var showIntervalPicker = false
    @State private var showDeniedAlert = false
    @State private var showHowTo = false
    @State private var showTip = false
    @State private var pendingInterval: Int = 5
    @State private var todaySessions: [ScrollSession] = []
    @State private var activeTier: TipTier = SharedStorage.shared.purchasedTier

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                elapsedSection
                intervalSection
                actionButton
                sessionsSection
            }
        }
        .background(Color.black)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showTip = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.appTextSecondary)
                    Text("tip.fab.label")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.appSurface)
                        .overlay(
                            Capsule().strokeBorder(Color.appBorder, lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
//            .padding(.bottom, 20)
        }
        .onAppear {
            notificationManager.checkAuthorization()
            pendingInterval = viewModel.selectedInterval
            if let start = SharedStorage.shared.activeTimers[scrollmateTimerKey] {
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
            todaySessions = SharedStorage.shared.todaySessions()
            activeTier = SharedStorage.shared.purchasedTier
        }
        // Refresh sessions when stop action arrives from notification banner (in-process only)
        .onReceive(NotificationCenter.default.publisher(for: scrollmateStopNotification)) { _ in
            elapsedSeconds = 0
            todaySessions = SharedStorage.shared.todaySessions()
        }
        // Single scenePhase observer — syncs all state when app returns to foreground
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            notificationManager.checkAuthorization()
            viewModel.syncState()
            if viewModel.isEnabled, let start = SharedStorage.shared.activeTimers[scrollmateTimerKey] {
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            } else {
                elapsedSeconds = 0
            }
            todaySessions = SharedStorage.shared.todaySessions()
        }
        .sheet(isPresented: $showTip, onDismiss: {
            activeTier = SharedStorage.shared.purchasedTier
        }) {
            TipView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#1c1c1c"))
        }
        .sheet(isPresented: $showIntervalPicker) {
            IntervalPickerSheet(
                pendingInterval: $pendingInterval,
                onConfirm: {
                    viewModel.intervalChanged(to: pendingInterval)
                    showIntervalPicker = false
                },
                onCancel: {
                    pendingInterval = viewModel.selectedInterval
                    showIntervalPicker = false
                }
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appSurface)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("greeting.title")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundColor(.appTextPrimary)
                Text("greeting.subtitle")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            Button {
                showHowTo = true
            } label: {
                logoRingView
                    .padding(.vertical, 4)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundColor(.appTextSecondary)
                            .offset(x: 12, y: -12)
                    }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showHowTo) {
            HowToView()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 36)
    }

    // MARK: Elapsed Time — always visible, hh:mm:ss

    private var elapsedSection: some View {
        Text(formattedElapsed)
            .font(.system(size: 61, weight: .thin, design: .monospaced))
            .foregroundColor(.appTextPrimary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 28)
            .onReceive(ticker) { _ in
                guard viewModel.isEnabled,
                      let start = SharedStorage.shared.activeTimers[scrollmateTimerKey] else { return }
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
    }

    // MARK: Interval — tap to open picker sheet

    private var intervalSection: some View {
        VStack(spacing: 8) {
            Text("interval.label")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.appTextSecondary)
        Button {
            pendingInterval = viewModel.selectedInterval
            showIntervalPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "\(viewModel.selectedInterval) \(String(localized: "unit.min"))")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.appTextPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 32)
    }

    // MARK: Start / Stop Button

    private var actionButton: some View {
        Button {
            if viewModel.isEnabled {
                viewModel.setEnabled(false)
                elapsedSeconds = 0
                todaySessions = SharedStorage.shared.todaySessions()
            } else {
                handleStartTapped()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isEnabled ? Color.appAccent : Color.green)
                    .frame(width: 80, height: 80)
                Image(systemName: viewModel.isEnabled ? "crown.fill" : "play.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .offset(x: viewModel.isEnabled ? 0 : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 36)
        .alert("permission.title", isPresented: $showDeniedAlert) {
            Button("permission.settings") { notificationManager.openAppSettings() }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("permission.body")
        }
    }

    // MARK: Start Action

    private func handleStartTapped() {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            Task {
                let granted = await notificationManager.requestAuthorization()
                if granted { viewModel.setEnabled(true) }
            }
        case .denied:
            showDeniedAlert = true
        case .authorized, .provisional, .ephemeral:
            viewModel.setEnabled(true)
        @unknown default:
            viewModel.setEnabled(true)
        }
    }

    // MARK: Today's Scrolls

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("session.title")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appTextSecondary)
                if !todaySessions.isEmpty {
                    Spacer()
                    Text(totalDurationLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.appTextSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            if todaySessions.isEmpty {
                Text("session.empty")
                    .font(.subheadline)
                    .foregroundColor(.appTabInactive)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(todaySessions.reversed()) { session in
                    SessionRowView(session: session)
                }
            }
        }
    }

    // MARK: Helpers

    // MARK: Logo with tier ring

    @ViewBuilder
    private var logoRingView: some View {
        let logo = Image("CircledLogoLight")
            .resizable()
            .scaledToFit()
            .frame(width: 60, height: 60)

        if let gradient = activeTier.ringGradient {
            logo
                .padding(3)
                .background(Circle().fill(gradient))
                .clipShape(Circle())
        } else {
            logo
                .padding(3)
                .background(Circle().fill(Color.appSurface))
                .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 1.5))
                .clipShape(Circle())
        }
    }

    // MARK: Tip tier ring gradients

    private var goldMetalGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "#B8860B"),
                Color(hex: "#FFD700"),
                Color(hex: "#FFFACD"),
                Color(hex: "#FFA500"),
                Color(hex: "#FFD700"),
                Color(hex: "#FFE066"),
                Color(hex: "#B8860B"),
            ],
            center: .center
        )
    }

    private var silverMetalGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "#aaaaaa"),
                Color(hex: "#eeeeee"),
                Color(hex: "#bbbbbb"),
                Color(hex: "#ffffff"),
                Color(hex: "#999999"),
                Color(hex: "#dddddd"),
                Color(hex: "#aaaaaa"),
            ],
            center: .center
        )
    }

    private var blueMetalGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "#1a6fb5"),
                Color(hex: "#56b4f5"),
                Color(hex: "#a8d8ff"),
                Color(hex: "#1d8eff"),
                Color(hex: "#56b4f5"),
                Color(hex: "#1a6fb5"),
            ],
            center: .center
        )
    }

    private var purpleMetalGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "#7b2fff"),
                Color(hex: "#c471ed"),
                Color(hex: "#f64f59"),
                Color(hex: "#c471ed"),
                Color(hex: "#7b2fff"),
                Color(hex: "#a855f7"),
                Color(hex: "#7b2fff"),
            ],
            center: .center
        )
    }

    private var totalDurationLabel: String {
        let total = Int(todaySessions.reduce(0) { $0 + $1.duration })
        return usageDurationLabel(seconds: total)
    }

    private var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
