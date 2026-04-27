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
                notificationBanner
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
                            Capsule().strokeBorder(Color.appAccent, lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            notificationManager.checkAuthorization()
            pendingInterval = viewModel.selectedInterval
            if let start = SyncEngine.shared.activeStartTime {
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
            if viewModel.isEnabled, let start = SyncEngine.shared.activeStartTime {
                elapsedSeconds = Int(Date().timeIntervalSince(start))
                // Replenish notifications in case they were exhausted while the app was in the background
                scheduleRepeatingNotification(
                    intervalMinutes: SharedStorage.shared.notificationInterval,
                    startTime: start
                )
            } else {
                elapsedSeconds = 0
            }
            todaySessions = SharedStorage.shared.todaySessions()
            activeTier = SharedStorage.shared.purchasedTier
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
                      let start = SyncEngine.shared.activeStartTime else { return }
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
    }

    // MARK: Start Action
    // Timer runs regardless of notification permission — notifications are an optional enhancement.

    private func handleStartTapped() {
        // Always start the session; notifications are an optional enhancement (App Review guideline 4.5.4).
        viewModel.setEnabled(true)

        // Request permission only on first launch; user can still proceed if they deny.
        if notificationManager.authorizationStatus == .notDetermined {
            Task { _ = await notificationManager.requestAuthorization() }
        }
    }

    // MARK: Notification Banner — shown only when permission is denied

    @ViewBuilder
    private var notificationBanner: some View {
        if notificationManager.authorizationStatus == .denied {
            Button {
                notificationManager.openAppSettings()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.appTextSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("permission.banner.title")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appTextPrimary)
                        Text("permission.banner.body")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.appTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.appBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
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
