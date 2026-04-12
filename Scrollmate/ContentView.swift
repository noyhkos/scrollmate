//
//  ContentView.swift
//  Scrollmate
//
//  Created by 김석현 on 2/11/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var notificationManager = NotificationManager.shared

    // Ticks every second to keep elapsed time display current
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var elapsedSeconds: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 32) {

                    // Elapsed time
                    if viewModel.isEnabled {
                        Text(formattedElapsed)
                            .font(.system(size: 52, weight: .thin, design: .monospaced))
                            .foregroundColor(.appTextPrimary)
                            .onReceive(ticker) { _ in
                                guard let start = SharedStorage.shared.activeTimers["scrollmate"] else { return }
                                elapsedSeconds = Int(Date().timeIntervalSince(start))
                            }
                    }

                    // Interval picker
                    VStack(spacing: 6) {
                        Text("알림 주기")
                            .font(.subheadline)
                            .foregroundColor(.appTextSecondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.appSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.appBorder, lineWidth: 1)
                                )

                            Picker("알림 주기", selection: Binding(
                                get: { viewModel.selectedInterval },
                                set: { viewModel.intervalChanged(to: $0) }
                            )) {
                                ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { minute in
                                    Text("\(minute)분")
                                        .foregroundColor(.appTextPrimary)
                                        .tag(minute)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 150)
                        }
                        .padding(.horizontal)
                    }

                    // Toggle
                    HStack {
                        Text("알림 켜기")
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isEnabled },
                            set: { newValue in
                                viewModel.setEnabled(newValue)
                                if !newValue { elapsedSeconds = 0 }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding()
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.appBorder, lineWidth: 1)
                    )
                    .padding(.horizontal)

                    if !notificationManager.isAuthorized {
                        Button("알림 권한 설정") {
                            notificationManager.openAppSettings()
                        }
                        .foregroundColor(.red)
                    }

                    // Test button — remove before release
                    Button("10초 알림 테스트") {
                        notificationManager.scheduleTestNotification()
                    }
                    .font(.footnote)
                    .foregroundColor(.appTextSecondary)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Scrollmate")
            .toolbarColorScheme(.none)
            .onAppear {
                notificationManager.checkAuthorization()
                if let start = SharedStorage.shared.activeTimers["scrollmate"] {
                    elapsedSeconds = Int(Date().timeIntervalSince(start))
                }
            }
        }
    }

    private var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    ContentView()
}
