import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var selectedInterval: Int

    init() {
        selectedInterval = SharedStorage.shared.notificationInterval
    }

    func saveSettings() {
        SharedStorage.shared.notificationInterval = selectedInterval
        print("저장 완료: \(selectedInterval)min")
    }
}