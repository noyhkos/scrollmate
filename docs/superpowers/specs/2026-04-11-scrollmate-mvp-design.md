# Scrollmate MVP Design

**Date:** 2026-04-11
**Minimum Deployment Target:** iOS 18

## Overview

Scrollmate is an iOS app that helps users manage SNS usage time via periodic notifications. This document covers the MVP feature set.

---

## 1. Home Screen — Notification Interval Setting

**Component:** `ContentView` (replaces current List-based UI)

- Wheel picker (`Picker` with `.pickerStyle(.wheel)`) to select interval (range: 1–60 min, 1-minute increments)
- Toggle switch to enable/disable notifications globally
- Changes apply immediately (no Save button)
- On toggle on: schedule repeating notifications using current interval
- On toggle off: cancel all pending notifications and stop timer

**Data flow:**
- Interval stored in `SharedStorage.notificationInterval`
- Active state stored in `SharedStorage.activeTimers` (empty = inactive)
- `SettingsViewModel` handles binding and writes

---

## 2. Home Screen Widget — 1x1 Small

**Target:** `ScrollmateWidget` (replaces current template)

- Size: `.systemSmall` only
- **Inactive state:** Green filled circle + SF Symbol `play.fill` (white icon)
- **Active state:** Red filled circle + SF Symbol `stop.fill` (white icon)
- Tap action via `AppIntent`: toggles timer on/off
- Reads state from `SharedStorage.activeTimers` via App Group
- On state change: calls `WidgetCenter.shared.reloadAllTimelines()`

---

## 3. Control Center Shortcut — ControlCenter Extension

**Target:** New `ScrollmateControlCenter` extension target

- Requires iOS 18+ (`ControlCenterExtension`)
- UI: 1x1 toggle button (same icon style as widget — `play.fill` / `stop.fill`)
- Inactive → green circle, Active → red circle
- Tap: toggles timer via `SharedStorage` + reloads widget timelines
- Shares state with app and widget via App Group

---

## 4. Notification — UNUserNotification Banner

**Component:** `NotificationManager` (extend existing)

**Scheduling:**
- On timer start: schedule repeating `UNTimeIntervalNotificationTrigger` with the configured interval
- Notification repeats until explicitly cancelled

**Category setup:**
```
category id: "SCROLLMATE_REMINDER"
options: [.customDismissAction]

actions:
  - "CONFIRM"  → title: "확인",  options: []
  - "STOP"     → title: "알림 끄기", options: [.destructive]
```

**Response handling (UNUserNotificationCenterDelegate):**

| User action | identifier | Behavior |
|---|---|---|
| Tap "확인" | `CONFIRM` | Dismiss notification, timer continues |
| Swipe away / ignore | `UNNotificationDismissActionIdentifier` | Same as "확인" |
| Tap "알림 끄기" | `STOP` | Cancel all pending notifications + stop timer |

**Notification content:**
- Title: "스크롤 중이세요?"
- Body: "SNS를 사용한 지 N분이 지났어요."

---

## Architecture Notes

- All shared state goes through `SharedStorage` (App Group: `group.com.scrollmate.app`)
- `TimerManager` owns timer start/stop logic and triggers widget reload
- `NotificationManager` owns scheduling and response handling
- Widget and Control Center extension read `SharedStorage` directly (no direct dependency on managers)
