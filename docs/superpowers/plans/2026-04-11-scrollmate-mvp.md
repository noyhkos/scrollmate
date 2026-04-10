# Scrollmate MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement MVP features — wheel picker home screen, notification scheduling with actions, 1x1 widget toggle, and Control Center shortcut.

**Architecture:** All shared state flows through `SharedStorage` (App Group). `NotificationManager` owns all UNUserNotification logic including scheduling and response handling. Widget and Control Center extensions each define their own `AppIntent` that writes to `SharedStorage` and schedules notifications directly via `UNUserNotificationCenter`. The main app toggle coordinates `TimerManager` + `NotificationManager`.

**Tech Stack:** SwiftUI, UserNotifications, WidgetKit, AppIntents, ControlCenter (iOS 18+)

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Scrollmate/ScrollmateApp.swift` | Modify | Remove test code, call setupNotificationCategory on launch |
| `Scrollmate/Managers/NotificationManager.swift` | Modify | Category setup, scheduling, cancel, response handling |
| `Scrollmate/ViewModels/SettingsViewModel.swift` | Modify | Add isEnabled toggle, coordinate TimerManager + NotificationManager |
| `Scrollmate/ContentView.swift` | Rewrite | Wheel picker (1–60분) + toggle UI |
| `ScrollmateWidget/AppIntent.swift` | Rewrite | Replace ConfigurationAppIntent with ToggleTimerIntent |
| `ScrollmateWidget/ScrollmateWidget.swift` | Rewrite | systemSmall widget with play/stop circle button |
| `ScrollmateWidget/ScrollmateWidgetBundle.swift` | Modify | Remove LiveActivity from bundle (or keep if needed) |
| `ScrollmateControlCenter/ScrollmateControlCenter.swift` | Create | ControlWidget with toggle button |
| `ScrollmateControlCenter/ScrollmateControlCenterBundle.swift` | Create | @main entry for control center extension |

---

### Task 1: Remove test code from ScrollmateApp.swift

**Files:**
- Modify: `Scrollmate/ScrollmateApp.swift`

- [ ] **Step 1: Remove hardcoded timer calls and add category setup**

Replace `Scrollmate/ScrollmateApp.swift` with:

```swift
import SwiftUI

@main
struct ScrollmateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                    NotificationManager.shared.setupNotificationCategory()
                }
        }
    }
}
```

- [ ] **Step 2: Commit (build verified after Task 2)**

```bash
git add Scrollmate/ScrollmateApp.swift
git commit -m "chore: remove test code from app entry point"
```

---

### Task 2: Extend NotificationManager

**Files:**
- Modify: `Scrollmate/Managers/NotificationManager.swift`

- [ ] **Step 1: Replace file with full implementation**

Replace `Scrollmate/Managers/NotificationManager.swift` with:

```swift
import Foundation
import UIKit
import UserNotifications
import WidgetKit
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            Task { @MainActor in
                self.isAuthorized = granted
            }
        }
    }

    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized
            Task { @MainActor in
                self.isAuthorized = authorized
            }
        }
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func setupNotificationCategory() {
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM",
            title: "확인",
            options: []
        )
        let stopAction = UNNotificationAction(
            identifier: "STOP",
            title: "알림 끄기",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: "SCROLLMATE_REMINDER",
            actions: [confirmAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func scheduleRepeatingNotification(intervalMinutes: Int) {
        cancelAllNotifications()

        let content = UNMutableNotificationContent()
        content.title = "스크롤 중이세요?"
        content.body = "SNS를 사용한 지 \(intervalMinutes)분이 지났어요."
        content.sound = .default
        content.categoryIdentifier = "SCROLLMATE_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(intervalMinutes * 60),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "scrollmate.reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show notification banner even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle tap on notification actions (including dismiss)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "STOP" {
            SharedStorage.shared.activeTimers = [:]
            cancelAllNotifications()
            WidgetCenter.shared.reloadAllTimelines()
        }
        // CONFIRM and UNNotificationDismissActionIdentifier → timer continues, do nothing
        completionHandler()
    }
}
```

- [ ] **Step 2: Build both Task 1 and Task 2 — Cmd+B**

Expected: Build succeeds (Tasks 1 + 2 together compile cleanly).

- [ ] **Step 3: Commit**

```bash
git add Scrollmate/Managers/NotificationManager.swift
git commit -m "feat: add notification scheduling and action handling"
```

---

### Task 3: Update SettingsViewModel

**Files:**
- Modify: `Scrollmate/ViewModels/SettingsViewModel.swift`

- [ ] **Step 1: Add isEnabled and coordinator methods**

Replace `Scrollmate/ViewModels/SettingsViewModel.swift` with:

```swift
import Foundation
import Combine

class SettingsViewModel: ObservableObject {
    @Published var selectedInterval: Int
    @Published var isEnabled: Bool

    init() {
        selectedInterval = SharedStorage.shared.notificationInterval
        isEnabled = !SharedStorage.shared.activeTimers.isEmpty
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            SharedStorage.shared.notificationInterval = selectedInterval
            TimerManager.shared.startTimer(for: "scrollmate")
            Task { @MainActor in
                NotificationManager.shared.scheduleRepeatingNotification(intervalMinutes: self.selectedInterval)
            }
        } else {
            TimerManager.shared.stopTimer(for: "scrollmate")
            Task { @MainActor in
                NotificationManager.shared.cancelAllNotifications()
            }
        }
    }

    func intervalChanged(to interval: Int) {
        selectedInterval = interval
        SharedStorage.shared.notificationInterval = interval
        if isEnabled {
            Task { @MainActor in
                NotificationManager.shared.scheduleRepeatingNotification(intervalMinutes: interval)
            }
        }
    }
}
```

- [ ] **Step 2: Build — Cmd+B**

Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Scrollmate/ViewModels/SettingsViewModel.swift
git commit -m "feat: add isEnabled toggle and interval sync to SettingsViewModel"
```

---

### Task 4: Rewrite ContentView

**Files:**
- Rewrite: `Scrollmate/ContentView.swift`

- [ ] **Step 1: Replace List UI with wheel picker + toggle**

Replace `Scrollmate/ContentView.swift` with:

```swift
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
```

- [ ] **Step 2: Build and run on simulator — Cmd+R**

Verify:
- Wheel picker shows 1~60분
- Toggle switches on/off
- Toggling on with notification permission granted → notification scheduled (check in Settings > Notifications)

- [ ] **Step 3: Commit**

```bash
git add Scrollmate/ContentView.swift
git commit -m "feat: replace list UI with wheel picker and toggle"
```

---

### Task 5: Rewrite Widget

**Files:**
- Rewrite: `ScrollmateWidget/AppIntent.swift`
- Rewrite: `ScrollmateWidget/ScrollmateWidget.swift`
- Modify: `ScrollmateWidget/ScrollmateWidgetBundle.swift`

**Pre-requisite — add SharedStorage to widget target:**
1. In Xcode Project Navigator, select `Scrollmate/Managers/sharedStorage.swift`
2. Open File Inspector (right panel, Cmd+Opt+1)
3. Under "Target Membership", check `ScrollmateWidget`

- [ ] **Step 1: Replace AppIntent.swift with ToggleTimerIntent**

Replace `ScrollmateWidget/AppIntent.swift` with:

```swift
import AppIntents
import UserNotifications
import WidgetKit

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate Timer"

    func perform() async throws -> some IntentResult {
        let isActive = !SharedStorage.shared.activeTimers.isEmpty

        if isActive {
            SharedStorage.shared.activeTimers = [:]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } else {
            SharedStorage.shared.addTimer(for: "scrollmate")

            let interval = SharedStorage.shared.notificationInterval
            let content = UNMutableNotificationContent()
            content.title = "스크롤 중이세요?"
            content.body = "SNS를 사용한 지 \(interval)분이 지났어요."
            content.sound = .default
            content.categoryIdentifier = "SCROLLMATE_REMINDER"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(interval * 60),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "scrollmate.reminder",
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

- [ ] **Step 2: Rewrite ScrollmateWidget.swift**

Replace `ScrollmateWidget/ScrollmateWidget.swift` with:

```swift
import WidgetKit
import SwiftUI
import AppIntents

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), isActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), isActive: !SharedStorage.shared.activeTimers.isEmpty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), isActive: !SharedStorage.shared.activeTimers.isEmpty)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct ScrollmateWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Button(intent: ToggleTimerIntent()) {
            ZStack {
                Circle()
                    .fill(entry.isActive ? Color.red : Color.green)
                    .frame(width: 64, height: 64)
                Image(systemName: entry.isActive ? "stop.fill" : "play.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.black, for: .widget)
    }
}

struct ScrollmateWidget: Widget {
    let kind: String = "ScrollmateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ScrollmateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Scrollmate")
        .description("알림을 시작하거나 종료합니다.")
        .supportedFamilies([.systemSmall])
    }
}
```

- [ ] **Step 3: Update ScrollmateWidgetBundle.swift — remove LiveActivity**

Replace `ScrollmateWidget/ScrollmateWidgetBundle.swift` with:

```swift
import WidgetKit
import SwiftUI

@main
struct ScrollmateWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScrollmateWidget()
    }
}
```

- [ ] **Step 4: Build widget target — select ScrollmateWidget scheme → Cmd+B**

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add ScrollmateWidget/AppIntent.swift ScrollmateWidget/ScrollmateWidget.swift ScrollmateWidget/ScrollmateWidgetBundle.swift
git commit -m "feat: implement 1x1 widget with play/stop toggle"
```

---

### Task 6: Add Control Center Extension

**Files:**
- Create: `ScrollmateControlCenter/ScrollmateControlCenter.swift`
- Create: `ScrollmateControlCenter/ScrollmateControlCenterBundle.swift`

**Pre-requisite — add new target in Xcode (manual):**
1. `File → New → Target`
2. Search "Control Center Extension" → Next
3. Product Name: `ScrollmateControlCenter`
4. Finish → Activate scheme when prompted

**Pre-requisite — add SharedStorage to new target:**
1. Select `Scrollmate/Managers/sharedStorage.swift` in Project Navigator
2. File Inspector → Target Membership → check `ScrollmateControlCenter`

**Pre-requisite — add App Group capability:**
1. Select `ScrollmateControlCenter` target → Signing & Capabilities
2. `+ Capability` → App Groups → add `group.com.scrollmate.app`

- [ ] **Step 1: Create ScrollmateControlCenter.swift**

Create `ScrollmateControlCenter/ScrollmateControlCenter.swift`:

```swift
import AppIntents
import ControlCenter
import UserNotifications
import WidgetKit

struct ScrollmateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlWidgetConfiguration(
            kind: "com.scrollmate.app.controlcenter"
        ) {
            ControlWidgetButton(action: ToggleControlIntent()) {
                Label("Scrollmate", systemImage: "play.fill")
            }
        }
        .displayName("Scrollmate")
        .description("알림 시작/종료")
    }
}

struct ToggleControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Scrollmate"

    func perform() async throws -> some IntentResult {
        let isActive = !SharedStorage.shared.activeTimers.isEmpty

        if isActive {
            SharedStorage.shared.activeTimers = [:]
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } else {
            SharedStorage.shared.addTimer(for: "scrollmate")

            let interval = SharedStorage.shared.notificationInterval
            let content = UNMutableNotificationContent()
            content.title = "스크롤 중이세요?"
            content.body = "SNS를 사용한 지 \(interval)분이 지났어요."
            content.sound = .default
            content.categoryIdentifier = "SCROLLMATE_REMINDER"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(interval * 60),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "scrollmate.reminder",
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
```

- [ ] **Step 2: Create ScrollmateControlCenterBundle.swift**

Create `ScrollmateControlCenter/ScrollmateControlCenterBundle.swift`:

```swift
import ControlCenter

@main
struct ScrollmateControlCenterBundle: ControlWidgetBundle {
    var body: some ControlWidget {
        ScrollmateControl()
    }
}
```

- [ ] **Step 3: Build ControlCenter target — select ScrollmateControlCenter scheme → Cmd+B**

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add ScrollmateControlCenter/
git commit -m "feat: add control center extension with toggle button"
```
