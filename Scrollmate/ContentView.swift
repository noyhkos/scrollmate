//
//  ContentView.swift
//  Scrollmate
//
//  Created by 김석현 on 2/11/26.
//

import SwiftUI
import Combine

// MARK: - App Tab

enum AppTab: CaseIterable {
    case scroll, stop, record, setting

    var label: String {
        switch self {
        case .scroll:  return "Scroll"
        case .stop:    return "Stop"
        case .record:  return "Record"
        case .setting: return "Setting"
        }
    }

    var icon: String {
        switch self {
        case .scroll:  return "scroll"
        case .stop:    return "hand.raised"
        case .record:  return "list.clipboard"
        case .setting: return "gearshape"
        }
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab: AppTab = .scroll
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Tab content — no bottom inset while tab bar is hidden
            ScrollTabView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // BottomTabBar hidden until remaining tabs are implemented
            // BottomTabBar(selectedTab: $selectedTab)
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

// MARK: - Scroll Tab

struct ScrollTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // .default mode yields during touch tracking — avoids blocking user input
    private let ticker = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    @State private var elapsedSeconds: Int = 0
    @State private var showIntervalPicker = false
    @State private var showDeniedAlert = false
    @State private var pendingInterval: Int = 5
    @State private var todaySessions: [ScrollSession] = []

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
        .onAppear {
            notificationManager.checkAuthorization()
            pendingInterval = viewModel.selectedInterval
            if let start = SharedStorage.shared.activeTimers["scrollmate"] {
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
            todaySessions = SharedStorage.shared.todaySessions()
        }
        // Refresh sessions when stop action arrives from notification banner (in-process only)
        .onReceive(NotificationCenter.default.publisher(for: kScrollmateStopNotification)) { _ in
            elapsedSeconds = 0
            todaySessions = SharedStorage.shared.todaySessions()
        }
        // Single scenePhase observer — syncs all state when app returns to foreground
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.syncState()
            if viewModel.isEnabled, let start = SharedStorage.shared.activeTimers["scrollmate"] {
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            } else {
                elapsedSeconds = 0
            }
            todaySessions = SharedStorage.shared.todaySessions()
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
                Text("G'day mate!")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundColor(.appTextPrimary)
                Text("Let's Scroll")
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(.appTextSecondary)
            }
            Spacer()
            Image("CircledLogoLight")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
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
                      let start = SharedStorage.shared.activeTimers["scrollmate"] else { return }
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
    }

    // MARK: Interval — tap to open picker sheet

    private var intervalSection: some View {
        Button {
            pendingInterval = viewModel.selectedInterval
            showIntervalPicker = true
        } label: {
            HStack(spacing: 6) {
                Text("\(viewModel.selectedInterval)분")
                    .font(.system(size: 20, weight: .regular, design: .serif))
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
        .padding(.bottom, 32)
    }

    // MARK: Start / End Toggle Button

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
        .alert("알림 권한이 필요해요", isPresented: $showDeniedAlert) {
            Button("설정으로 이동") { notificationManager.openAppSettings() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("스크롤 알림을 받으려면 설정에서 알림 권한을 허용해 주세요.")
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
            Text("Today's Scrolls")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.appTextSecondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            if todaySessions.isEmpty {
                Text("No sessions yet")
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

    private var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Session Row

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

// MARK: - Interval Picker Sheet

struct IntervalPickerSheet: View {
    @Binding var pendingInterval: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area + confirm button
            HStack {
                Button("취소") { onCancel() }
                    .foregroundColor(.appTextSecondary)
                    .font(.system(size: 16))

                Spacer()

                Button("확인") { onConfirm() }
                    .foregroundColor(.appAccent)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            Picker("", selection: $pendingInterval) {
                ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { minute in
                    Text("\(minute)분")
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

#Preview {
    ContentView()
}
