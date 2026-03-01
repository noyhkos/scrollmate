//
//  ScrollmateApp.swift
//  Scrollmate
//
//  Created by 김석현 on 2/11/26.
//

import SwiftUI

@main
struct ScrollmateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
