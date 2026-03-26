# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a macOS SwiftUI app built with Xcode. No SPM dependencies or test targets exist.

```bash
# Build
xcodebuild -project MyLaunchpad.xcodeproj -scheme MyLaunchpad -configuration Debug build

# Build and run (opens the app)
xcodebuild -project MyLaunchpad.xcodeproj -scheme MyLaunchpad -configuration Debug build && open build/Debug/MyLaunchpad.app
```

- **Deployment target:** macOS 26.4
- **Bundle ID:** `com.func.MyLaunchpad`
- **Swift version:** 5.0
- **No third-party dependencies**

## Architecture

MyLaunchpad is a custom macOS Launchpad replacement — a fullscreen overlay that displays installed apps in a paginated grid with drag-to-reorder and folder support.

### Core data flow

1. **AppManager** (`@Observable`, `@MainActor`) is the single source of truth. It discovers apps from `/Applications` and `/System/Applications`, syncs with a persisted JSON layout (`~/Library/Application Support/MyLaunchpad_Layout.json`), and exposes `items: [LaunchpadItem]` plus a computed `pagedItems` (35 items per page).

2. **LaunchpadItem** is an enum: `.app(AppInfo)` or `.folder(id, name, apps)`. `AppInfo` holds `id`, `name`, `path`, and a runtime `icon: NSImage` (excluded from Codable). AppManager uses a separate internal `StoredAppInfo`/`StoredLaunchpadItem` for persistence (no icon).

3. **ContentView** owns the `AppManager` via `@State`, manages all drag-and-drop coordination (reorder, merge into folder via Option+drag, page turning at screen edges), and tracks item positions via `PreferenceKey` frame reporting.

### Window management

`MyLaunchpadApp` uses `AppDelegate` with the Carbon Events API to register a global hotkey (**Ctrl+Option+Cmd+L**). The window is configured as a borderless, transparent fullscreen overlay (`canJoinAllSpaces`, `stationary`, `ignoresCycle`). Show/hide uses alpha animation and `NotificationCenter` notifications (`.toggleLaunchpad`, `.hideLaunchpad`). Escape key also hides via a local `NSEvent` key monitor.

### Drag & drop mechanics

- Reorder: dragging moves the item in `AppManager.items` when hovering over another item
- Merge: **Option+drag** onto another item creates a folder (default name: "新建文件夹")
- Folder escape: dragging an app 200+ points outside a folder overlay extracts it and transitions to main grid drag
- Page turning: dragging to screen edges (80pt threshold) with 0.5s debounce

### View components (`Views/Components/`)

- **AppIconView** / **FolderIconView**: grid cells with tap, drag gesture, and merge-target highlight. Use `expandsToGridCell` flag to toggle between grid layout and floating drag ghost.
- **FolderOverlayView**: fullscreen modal with internal reorder, app extraction, and folder rename via inline `TextField`.
- **VisualEffectView**: `NSViewRepresentable` wrapper for `NSVisualEffectView`.
