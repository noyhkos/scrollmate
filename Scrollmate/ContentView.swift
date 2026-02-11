//
//  ContentView.swift
//  Scrollmate
//
//  Created by 김석현 on 2/11/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedInterval: Int = SharedStorage.shared.notificationInterval

    let intervals: [Int] = [5, 10, 15, 20, 25, 30]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Reminder Interval")) {
                    ForEach(intervals, id: \.self) { interval in
                        Button(action: {
                            selectedInterval = interval
                        }) {
                            HStack {
                                Text("\(interval) minutes")
                                Spacer()
                                Image(systemName: selectedInterval == interval 
                                    ? "checkmark.circle.fill" 
                                    : "circle")
                                    .foregroundColor(selectedInterval == interval 
                                        ? .blue
                                        : .gray)
                            }
                        }
                    }
                    Button("Save") {
                        SharedStorage.shared.notificationInterval = selectedInterval
                        print("저장 완료: \(selectedInterval)min")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Scrollmate")
        }
    }
}

#Preview {
    ContentView()
}
