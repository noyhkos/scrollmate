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

    let intervals: [Int] = [5, 10, 15, 20, 25, 30]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Reminder Interval")) {
                    ForEach(intervals, id: \.self) { interval in
                        Button(action: {
                            viewModel.selectedInterval = interval
                        }) {
                            HStack {
                                Text("\(interval) minutes")
                                Spacer()
                                Image(systemName: viewModel.selectedInterval == interval 
                                    ? "checkmark.circle.fill" 
                                    : "circle")
                                    .foregroundColor(viewModel.selectedInterval == interval 
                                        ? .blue
                                        : .gray)
                            }
                        }
                    }
                    Button("Save") {
                        viewModel.saveSettings()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }

                Section(header: Text("Notifications")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                        .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    if !notificationManager.isAuthorized {
                        Button("Open Settings") {
                            notificationManager.openAppSettings()
                        }
                    }
                }
            }
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
