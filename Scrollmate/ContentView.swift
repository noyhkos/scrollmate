//
//  ContentView.swift
//  Scrollmate
//
//  Created by 김석현 on 2/11/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var notificationManager = NotificationManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("알림 주기")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("알림 주기", selection: Binding(
                        get: { viewModel.selectedInterval },
                        set: { viewModel.intervalChanged(to: $0) }
                    )) {
                        ForEach(1...60, id: \.self) { minute in
                            Text("\(minute)분").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                Toggle("알림 켜기", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { viewModel.setEnabled($0) }
                ))
                .padding(.horizontal)

                if !notificationManager.isAuthorized {
                    Button("알림 권한 설정") {
                        notificationManager.openAppSettings()
                    }
                    .foregroundColor(.red)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Scrollmate")
            .onAppear {
                notificationManager.checkAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
}
