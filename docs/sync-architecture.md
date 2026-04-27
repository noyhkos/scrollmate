# Cross-Process State Sync Architecture

How Scrollmate keeps four UI surfaces (in-app toggle, home widget, lock screen
widget, Control Center) in sync without a backend, and the iOS-side
limitations we worked around.

> **TL;DR**: The four surfaces share state through an App Group container —
> UserDefaults plus an atomic mirror file. A single type, `SyncEngine`, owns
> every state mutation. Reads prefer the atomic file. Writes trigger a
> three-pass reload of all surfaces. The remaining lag (~hundreds of ms in the
> worst case) is bounded by an iOS 18 system limitation that an Apple engineer
> has [acknowledged on the developer
> forums](https://developer.apple.com/forums/thread/763689).

---

## 1. The problem

iOS apps cannot freely share live state across processes. WidgetKit, Control
Widgets, AppIntents, and the main app each run in their own execution
contexts, and Apple does not expose a synchronous "broadcast my new state
everywhere" API. Without care, a toggle flipped in one surface can leave
another surface displaying stale visuals for seconds — or until the user
naturally interacts with the system UI again.

Scrollmate has four surfaces that can each start or stop a session:

| Surface              | Process                                | Toggled via                                  |
| -------------------- | -------------------------------------- | -------------------------------------------- |
| Main app             | `Scrollmate` (main)                    | SwiftUI `Button` → `SettingsViewModel`        |
| Home screen widget   | `ScrollmateWidgetExtension`            | `ToggleTimerIntent` (AppIntent)              |
| Lock screen widget   | `ScrollmateWidgetExtension` (same)     | `ToggleTimerIntent` (AppIntent)              |
| Control Center       | `ScrollmateWidgetExtension` (same)     | `ToggleScrollmateIntent` (SetValueIntent)    |
| Notification action  | Main app (delegate-launched)           | `STOP` action on reminder notification       |

All five entry points must converge on the same observable state — and any
change on one must propagate to the rest within a perceptually short window.

---

## 2. The iOS-side limits we cannot fix

These are upstream constraints. No amount of app-side engineering removes
them. Each remaining one in our stack is mitigated, not eliminated.

### 2.1. AppIntent reloads run "outside the app's execution scope"

Quoted directly from an Apple engineer reply on the developer forums
(thread 763689):

> *You cannot reliably reload all controls from inside an AppIntent that is
> running outside of the App's execution scope. You can only get a definite
> reload if you call that from your running app.*

Practical consequence: when the widget extension calls
`ControlCenter.shared.reloadControls(ofKind:)`, the system may delay or drop
the request. The same call from the main app process is more likely to be
honored.

### 2.2. `ControlValueProvider.currentValue()` is queried lazily

Apple's [WidgetKit / ControlCenter
documentation](https://developer.apple.com/documentation/widgetkit/controlcenter)
describes `reloadControls(ofKind:)` as a request, not a command. The system
decides when to invoke `currentValue()`. Three deterministic triggers exist:

1. After an action completes (the intent's `perform()` returns).
2. When the app explicitly requests a reload.
3. When a push notification invalidates the control.

Outside those, the system favors batching and battery preservation over
immediacy. There is no synchronous "render now" API.

### 2.3. App Group `UserDefaults` flush is eventually consistent

Writes from one process are not immediately visible in another. The
documented order of operations is "writes are visible after the system
flushes" with no guaranteed timing. Empirically, propagation takes tens to
hundreds of milliseconds; under memory pressure or low-power mode it can
take longer. `UserDefaults.synchronize()` is deprecated for app-private
storage but [remains valid for cross-process
visibility](https://developer.apple.com/forums/thread/710966) — Apple's
deprecation note specifically permits the cross-process use case.

### 2.4. Widget extensions can be suspended mid-task

The widget extension process gets only a brief lifetime per AppIntent
invocation. After the intent's `perform()` returns, iOS may suspend the
extension within seconds. Any `Task.detached` that the intent kicked off
risks being killed before its work runs.

### 2.5. Notification action handlers run in a background-launched app

When the user taps a notification action while the app is not running, iOS
launches the app in the background to call its delegate, then suspends it
shortly after. Calling the completion handler too early signals iOS that the
work is done, releasing it to suspend mid-cleanup.

### 2.6. Lock-screen detection is unavailable to suspended apps

`UIApplication.protectedDataWillBecomeUnavailable` and friends only fire
while the app is running. Suspended apps cannot observe device lock events
in real time. This rules out "auto-stop on lock" as a real-time feature.

---

## 3. Architecture

### 3.1. Single source of truth

Everything authoritative about session state lives in a single App Group
container, shared by both targets:

```
group.com.scrollmate.app/
├── (App Group UserDefaults)
│   ├── activeTimers       : [String: Date]   ← legacy SoT, preserved for compat
│   ├── notificationInterval : Int
│   ├── scrollSessions     : [ScrollSession]  (encoded)
│   ├── tipTier            : Int
│   ├── stateVersion       : Int              ← bumped on every write
│   └── stateUpdatedAt     : Date             ← timestamp of last write
└── state.json                                ← atomic mirror for fast cross-process reads
```

`state.json` mirrors only the active-state subset:

```swift
struct SyncStateMirror: Codable, Sendable {
    let isActive: Bool
    let startTime: Date?
    let version: Int
    let updatedAt: Date
}
```

Why a separate file? POSIX `rename` (which `Data.write(options: .atomic)`
uses on Apple platforms) provides stronger cross-process visibility
guarantees than App Group `UserDefaults`. The reading process either sees
the entire old file or the entire new file — no partial states, no
deferred-flush window.

Other state (sessions history, tip tier) stays UserDefaults-only. It doesn't
need fast cross-process visibility, and migrating it would risk corrupting
existing user data.

### 3.2. Single write path: `SyncEngine`

All state mutations funnel through `SyncEngine` (defined in
`Scrollmate/Managers/SyncEngine.swift`). It exposes:

| API                                  | Purpose                                                    |
| ------------------------------------ | ---------------------------------------------------------- |
| `var isActive: Bool`                 | File-first read, UserDefaults fallback                     |
| `var activeStartTime: Date?`         | Same pattern, returns the start time                       |
| `func startSession(intervalMinutes:)`| Begin a session (write SoT, schedule notifs, reload, Darwin) |
| `func stopSession() -> ScrollSession?`| End a session (save to history, reload, Darwin)           |
| `func toggle()`                       | Toggle based on current state — used by widget/CC intents |
| `func resyncFromStorage()`           | Full reconciliation; called on `scenePhase .active`         |
| `func reloadAllSurfaces()`           | Public reload hook (multi-pass) for Darwin observers       |

Three callers use it:

1. `SettingsViewModel.setEnabled` — in-app toggle.
2. `ToggleTimerIntent.perform` / `ToggleScrollmateIntent.perform` — widget,
   lock screen widget, Control Center.
3. `NotificationManager.didReceive` STOP path — notification action.

Because there is exactly one place that mutates state, new race conditions
cannot easily creep in. Adding a fifth surface in the future means writing
one new caller, not duplicating three reload patterns.

### 3.3. Read path: file-first

```swift
var isActive: Bool {
    if let mirror = SharedStorage.shared.readStateMirror() {
        return mirror.isActive
    }
    SharedStorage.shared.forceSync()                    // fallback: flush + UserDefaults
    return !SharedStorage.shared.activeTimers.isEmpty
}
```

The atomic mirror is read first; if it is missing (e.g., the user is
upgrading from a build before SyncEngine existed), we fall back to a
`synchronize()`'d UserDefaults read.

### 3.4. Write path: multi-pass reload + Darwin signal

```swift
func startSession(intervalMinutes: Int) {
    let now = Date()
    SharedStorage.shared.activeTimers[scrollmateTimerKey] = now      // 1
    SharedStorage.shared.notificationInterval = intervalMinutes
    bumpStateVersion()                                                // 2
    writeMirror(isActive: true, startTime: now)                       // 3

    sendStartNotification(intervalMinutes: intervalMinutes)
    Task.detached { scheduleRepeatingNotification(...) }

    scheduleMultiPassReload()                                          // 4
    postDarwinStateChanged()                                           // 5
}
```

1. Update App Group UserDefaults.
2. Bump `stateVersion` and `stateUpdatedAt` (currently used for staleness
   debugging; future races could be detected via version comparisons).
3. Atomic-write `state.json` so the next cross-process read sees the new
   value immediately.
4. Schedule three reload passes: now+200ms, now+1s, now+3.5s. iOS 18
   sometimes silently drops the first request; later passes catch the gap.
5. Post a Darwin notification so the *other* process (the main app) can
   observe the change and reload too.

### 3.5. AppIntent suspension hold

After an intent's `perform()` returns, iOS can suspend the widget extension
within a few seconds. The detached reload Task scheduled at 1s and 3.5s
might never run. Mitigation: hold the intent open for 300ms via
`Task.sleep`.

```swift
func perform() async throws -> some IntentResult {
    SyncEngine.shared.toggle()
    try? await Task.sleep(nanoseconds: 300_000_000)   // keep extension alive
    return .result()
}
```

This guarantees the first reload pass at 200ms fires before iOS releases
the extension. The user does not perceive the 300ms delay because Control
Center / widget visuals flip optimistically on tap.

### 3.6. Notification STOP completion deferral

The notification delegate's completion handler is captured as
`nonisolated(unsafe)` and only invoked after the cleanup Task completes,
keeping iOS from suspending the background-launched app mid-task:

```swift
nonisolated(unsafe) let completion = completionHandler
Task { @MainActor in
    defer { completion() }
    SyncEngine.shared.stopSession()
    try? await Task.sleep(nanoseconds: 250_000_000)   // first reload pass starts at 200ms
    NotificationCenter.default.post(name: scrollmateStopNotification, object: nil)
}
```

### 3.7. Darwin observer in the main app

The main app installs a Darwin observer at launch. When the widget
extension posts `com.scrollmate.stateChanged`, the observer triggers
another full multi-pass reload — this time from the main app's process,
which Apple's documented reliability guarantees apply to.

```swift
CFNotificationCenterAddObserver(
    CFNotificationCenterGetDarwinNotifyCenter(), nil,
    { _, _, _, _, _ in
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .scrollmateWidgetStateChanged, object: nil)
            SyncEngine.shared.reloadAllSurfaces()
        }
    },
    darwinStateChangedNotification as CFString,
    nil, .deliverImmediately
)
```

Net effect: state changes originated by the widget extension are reloaded
twice — once from the extension (best-effort, per Apple's caveat) and once
from the main app (definite). The redundancy is intentional.

### 3.8. Foreground self-heal

When `scenePhase` becomes `.active`, the main app forces a full
reconciliation: re-read SoT, rewrite the mirror in case it drifted, and
issue another multi-pass reload. This guarantees the in-app UI is correct
after any background absence regardless of what happened while suspended.

```swift
.onChange(of: scenePhase) { _, phase in
    guard phase == .active else { return }
    notificationManager.checkAuthorization()
    viewModel.syncState()        // calls SyncEngine.resyncFromStorage()
    ...
}
```

---

## 4. Layer summary

| Layer                                 | Where                                        | Defends against                                        |
| ------------------------------------- | -------------------------------------------- | ------------------------------------------------------ |
| Atomic mirror file (`state.json`)     | `SharedStorage.writeStateMirror`             | UserDefaults flush latency                             |
| File-first read with sync fallback    | `SyncEngine.isActive` / `activeStartTime`    | Stale UserDefaults reads in widget process             |
| `forceSync()` on fallback             | `SyncEngine.isActive` / `resyncFromStorage`  | Stuck UserDefaults cache in widget process             |
| `stateVersion` + `stateUpdatedAt`     | `SharedStorage`, bumped by `SyncEngine`      | Future race detection / debug visibility               |
| Multi-pass reload (200ms / 1s / 3.5s) | `SyncEngine.scheduleMultiPassReload`         | iOS dropping individual reload requests                |
| Kind-specific reload                  | `ControlCenter.reloadControls(ofKind:)`      | (Per WWDC24) more responsive than `reloadAllControls()`|
| Darwin notification (post + observe)  | `SyncEngine` + `ScrollmateApp`               | Cross-process invalidation                             |
| AppIntent 300ms hold                  | `ToggleTimerIntent`, `ToggleScrollmateIntent`| Widget extension suspension before first reload        |
| STOP completion deferral              | `NotificationManager.didReceive`             | Background-launched app suspending mid-cleanup         |
| `scenePhase .active` resync           | `SettingsViewModel.syncState`                | Drift accumulated while app was suspended              |

---

## 5. What we deliberately did not do

- **Push notification invalidation** (Apple's WWDC24 third reload trigger):
  rejected because it requires a server, conflicting with Scrollmate's
  no-backend principle.

- **`openAppWhenRun = true`** on widget intents: rejected because it
  defeats the entire point of a widget toggle. Users want quick action
  without their flow being interrupted by an app launch.

- **Auto-stop on device lock**: not feasible. Suspended apps cannot
  observe lock events. The closest viable approximation is heuristic-based
  (e.g., auto-stop after N consecutive ignored reminders), considered for
  a future release.

- **Replacing UserDefaults with a single file SoT**: would require
  migrating existing user data (session history, tip tier) and risks
  corruption. The hybrid approach (mirror file for hot active-state, keep
  UserDefaults for cold storage) provides most of the benefit at near-zero
  migration risk.

- **`UNNotificationServiceExtension`** for state inspection: only fires for
  remote push notifications, not local time-trigger reminders. Useless
  for our case.

---

## 6. Testing the system

### 6.1. WidgetKit Developer Mode

Apple ships a [developer mode for
WidgetKit](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
that removes throttling on widget refreshes. Enable it for measurement:

1. iOS Settings → Developer → WidgetKit Developer Mode → ON.
2. Re-test sync scenarios. Reload latency drops dramatically.
3. The presence of throttling in the production environment is what makes
   our multi-pass strategy worthwhile.

### 6.2. Manual test scenarios

| # | Scenario                                                              | Expected           |
| - | --------------------------------------------------------------------- | ------------------ |
| 1 | Start session in app → immediately open Control Center                | CC shows ON        |
| 2 | Start session via Control Center → immediately open app               | App shows ON       |
| 3 | Start via home widget → check lock screen widget                      | Lock widget ON     |
| 4 | Tap STOP from a notification while the app is killed                  | All surfaces OFF on next foreground |
| 5 | Force-quit app → toggle home widget → relaunch app                    | App reflects widget state |
| 6 | Rapid alternating toggles across surfaces (widget → CC → widget)      | Final state is consistent everywhere |

### 6.3. Diagnostic surfaces

- `SharedStorage.shared.stateVersion` — increments monotonically with every
  toggle. Useful for validating that writes are landing.
- `SharedStorage.shared.stateUpdatedAt` — timestamp of last write.
- `state.json` in the App Group container — readable from a debug build
  to confirm the mirror is current.

---

## 7. References

- Apple Developer Forums: [AppIntent — Widget &
  ControlWidget](https://developer.apple.com/forums/thread/763689) — Apple
  engineer confirms in-extension reloads are best-effort.
- WWDC24 Session 10157: [Extend your app's controls across the
  system](https://developer.apple.com/videos/play/wwdc2024/10157/) —
  recommends `reloadControls(ofKind:)` and the TimerManager pattern.
- Apple Developer Documentation:
  [`ControlCenter`](https://developer.apple.com/documentation/widgetkit/controlcenter),
  [Keeping a widget up to
  date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).
- Feedback Assistant: [FB11522170 — Reloading widget timeline from an
  AppIntent does not reload the timeline
  immediately](https://github.com/feedback-assistant/reports/issues/359) —
  community-tracked iOS bug report.
- `CCHDarwinNotificationCenter` — reference Darwin notification wrapper:
  [github.com/choefele/CCHDarwinNotificationCenter](https://github.com/choefele/CCHDarwinNotificationCenter).

---

## 8. Living document

Update this file whenever you change anything that affects sync semantics:

- Adding a new toggle surface → update §1, §3.2, §4.
- Replacing UserDefaults or the mirror file → update §3.1.
- Changing reload timing → update §3.4 and §4.
- Discovering a new iOS limitation → add to §2 with a citation.

The goal is that any future contributor can understand *why* each layer
exists without re-discovering the constraints from scratch.
