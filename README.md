<div align="center">
  <img src="assets/icon.png" width="160" alt="RetroLaunchpad Logo">

  # RetroLaunchpad

  **The Ultimate Launchpad Revival for macOS 26**

  *"When Apple removed Launchpad in macOS 26, we brought it back with pure SwiftUI — and made it better."*

  [![macOS 26+](https://img.shields.io/badge/macOS-26.0%2B-black.svg?style=for-the-badge&logo=apple)](#)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-Pure-blue.svg?style=for-the-badge&logo=swift)](#)
  [![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](#)
  [![Release](https://img.shields.io/github/v/release/yourname/RetroLaunchpad?style=for-the-badge)](#)

  **[English](README.md)** | **[中文](README-ZH.md)**
</div>

---

## Preview

> **Tip:** Place a stunning WebP animation here.
> *Showcasing: hotkey activation -> Liquid Glass background -> 120Hz silky drag across pages -> spring folder merge -> focus-loss exit.*

*(Placeholder: `![Demo](assets/demo.webp)`)*

## The Story

In the macOS 26 major update, Apple officially retired the classic Launchpad that had been with us for over a decade. While new app management paradigms emerged, the muscle memory of swiping through a fullscreen grid of icons left many long-time Mac users longing for what was lost.

**RetroLaunchpad** is not mere nostalgia — it's a technical showcase. Built with pure SwiftUI, embracing Apple's latest **Liquid Glass** design language, and powered by a completely custom drag engine. It's smoother than the original, and smarter than the system.

## Features

### 1. Liquid Glass UI
- **Deep frosted-glass refraction** — Perfectly aligned with the macOS 26 Liquid Glass design language. Fullscreen, borderless, with real-time light diffusion and depth.
- **System-level stealth** — Runs as a background daemon with menu bar and Dock presence. **Auto-hides instantly on focus loss**, leaving no trace.

### 2. Physics-Driven Drag Engine
- **120Hz full-frame fluidity** — Ditches the system's default drag jank. Custom coordinate system delivers zero-latency, pixel-perfect tracking.
- **Dynamic physics feedback** — Cross-page flipping with rubber-band damping. Every drag interaction carries real momentum and spring elasticity.

### 3. Native Folder Management
- **Full folder lifecycle** — Drag-to-merge auto-creates folders, internal grid reordering, drag-to-escape dissolves them. Animations flow seamlessly.
- **iOS-style jiggle mode** — Hold Option to enter the familiar jiggle mode for precise uninstall and rearrangement. Powered by `drawingGroup` off-screen rendering — a thousand icons jiggling at once without breaking a sweat.

### 4. Lightning Fast
- **Global hotkey** — `Option + Space` summons the launchpad instantly, faster than Spotlight.
- **Smart sync** — Automatically detects newly installed apps. Local JSON layout file enables millisecond-level loading and persistent memory.

---

## Installation

### Option 1: Download .dmg (Recommended)
1. Head to the [Releases](#) page and download the latest `RetroLaunchpad.dmg`.
2. Open the DMG and drag `RetroLaunchpad.app` into your `Applications` folder.
3. On first launch, grant **Accessibility** permission in System Settings to enable the global hotkey.

> **Warning: Bypassing macOS Gatekeeper**
>
> This project is not yet signed with an Apple Developer certificate. macOS may show a **"cannot be opened"** or **"is damaged"** warning on first launch. This is **not** actual corruption — it's macOS's default quarantine policy for unsigned apps.
>
> After dragging the app to `Applications`, open **Terminal** and run:
>
> ```bash
> sudo xattr -rd com.apple.quarantine /Applications/RetroLaunchpad.app
> ```
>
> Enter your Mac login password and press Enter. You can then launch the app normally.

### Option 2: Homebrew Cask (Coming Soon)
```bash
brew install --cask retrolaunchpad
```

---

## Under the Hood

For developers, here are some of the hardcore optimizations under the surface:

- **How did we solve the thousand-icon jiggle rendering catastrophe?**
  Each app icon layer is wrapped in `drawingGroup()`, forcing Metal off-screen rasterization. Combined with deterministic phase-alternating Spring animations, CPU usage dropped from 80% to under 5%.
- **How is the absolute coordinate drag system built?**
  We abandoned the native `onDrag` / `onDrop` APIs — they don't offer frame-level granularity. Instead, we combine `DragGesture` with `GeometryReader` in the global coordinate space, using Euclidean distance-based nearest-center hit detection for pixel-perfect collision.

## Roadmap

- [x] Core physics engine & Liquid Glass UI
- [x] Jiggle mode with uninstall logic & rendering optimization
- [x] Local JSON layout persistence & dynamic sync
- [x] Safety mechanisms (uninstall confirmation alert + hierarchical dismissal)
- [x] Multi-monitor intelligent tracking & adaptation
- [x] Native Settings window (launch at login / hidden app management / layout reset)
- [x] Entrance/exit depth animations (scale + blur + opacity spring)
- [ ] Keyboard arrow/Tab focus navigation (Accessibility)
- [ ] Custom global hotkey configuration
- [ ] Homebrew Cask distribution

## Contributing

Found a bug? Have a better animation tuning idea? Issues and PRs are welcome!
Please make sure your changes don't break the existing coordinate engine logic before submitting a PR.

## License

This project is licensed under the [MIT License](LICENSE).

*Designed & Handcrafted with love in 2026*
