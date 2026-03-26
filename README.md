<div align="center">
  <!-- 占位：应用图标 (512x512 PNG，流态玻璃风格) -->
  <img src="assets/icon.png" width="160" alt="RetroLaunchpad Logo">
  
  # RetroLaunchpad
  
  **macOS 26 启动台的终极复刻与超越**
  
  *“当苹果在 macOS 26 移除了 Launchpad，我们用纯 SwiftUI 把它带了回来，并赋予它新生。”*

  <!-- 徽章区域 -->
  [![macOS 26+](https://img.shields.io/badge/macOS-26.0%2B-black.svg?style=for-the-badge&logo=apple)](#)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-Pure-blue.svg?style=for-the-badge&logo=swift)](#)
  [![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](#)
  [![Release](https://img.shields.io/github/v/release/yourname/RetroLaunchpad?style=for-the-badge)](#)
</div>

---

## 🌌 视觉预览 (Preview)

> **💡 建议：** 在这里放置一张极其惊艳的 WebP 动图。
> *场景包含：快捷键唤醒 -> 流态玻璃背景显现 -> 120Hz 丝滑拖拽 App 跨页 -> 丢入文件夹的弹性动画 -> 失焦优雅退出。*

*(占位图：`![Demo](assets/demo.webp)`)*

## 📖 诞生背景 (The Story)

在 macOS 26 的大版本更新中，苹果正式移除了陪伴我们多年的传统 Launchpad。虽然有了新的应用管理方式，但那种全屏沉浸、指尖划过无数图标的肌肉记忆，依然让许多老 Mac 用户难以释怀。

**RetroLaunchpad** 不是一次简单的怀旧，而是一场技术与设计的炫技。我们采用纯 SwiftUI，融入最新的 **“流态玻璃（Liquid Glass）”** 设计语言，彻底重写了底层拖拽逻辑。它比原生更流畅，比系统更懂你。

## ✨ 核心特性 (Features)

### 💧 1. 流态玻璃，原生沉浸 (Liquid Glass UI)
- **极致的毛玻璃折射**：完美贴合 macOS 26 全新的 Liquid Glass 设计语言，全屏无边框，带来深度折射感与光影跟随。
- **系统级潜伏**：基于 `LSUIElement` 打造的纯后台守护进程，支持托盘管理与 Dock 栏驻留，**失焦瞬间自动隐匿**，不留痕迹。

### 🕹 2. 绝对坐标物理拖拽引擎 (Physics-Driven Engine)
- **120Hz 满帧丝滑**：摒弃系统默认的拖拽卡顿，自研坐标系，实现“指哪打哪”的零延迟跟随。
- **动态物理反馈**：跨页翻页、橡皮筋阻尼回弹，每一次拖拽都能感受到真实的物理重力与弹性。

### 📂 3. 完美复刻的收纳逻辑 (Native Management)
- **自由的文件夹生态**：支持拖拽重叠自动建包、内部网格重排、向外逃逸解散，动画一气呵成。
- **iOS 级抖动模式**：长按进入熟悉的抖动模式，精细化卸载与重排。通过 `drawingGroup` 离屏渲染硬核优化，千个图标同时抖动亦稳如泰山。

### ⚡ 4. 肌肉记忆，一键瞬发 (Lightning Fast)
- **全局快捷键**：默认支持 `Option + Space`（可自定义）瞬间唤醒，比 Spotlight 更快。
- **智能同步**：自动监听并抓取系统新安装的 App，基于本地 JSON 布局文件实现毫秒级加载与持久化记忆。

---

## 🚀 安装指南 (Installation)

### 方式一：下载 .dmg (推荐)
1. 前往 [Releases](#) 页面下载最新的 `RetroLaunchpad.dmg`。
2. 打开并将 `RetroLaunchpad.app` 拖入 `Applications` 文件夹。
3. 首次运行请在系统设置中授予**“辅助功能（Accessibility）”**权限，以确保全局快捷键正常工作。

### 方式二：Homebrew Cask (准备中)
```bash
brew install --cask retrolaunchpad
```
---

## 🛠 技术揭秘 (Under the Hood)

对于开发者，这里有一些我们在性能优化上的硬核实践：

- **如何解决千图抖动的渲染灾难？**
  我们将每个应用图标层包裹在 `drawingGroup()` 中，强制 Metal 进行离屏渲染，结合 `AnimatableModifier` 处理相位随机的 Spring 动画，成功将 CPU 占用从 80% 压到了 5% 以下。
- **拖拽系统的绝对坐标是如何建立的？**
  抛弃了原生的 `onDrag` / `onDrop`，因为它们无法提供细粒度的帧级控制。我们通过组合 `DragGesture` 与 `GeometryReader` 全局坐标域（`.named("LaunchpadSpace")`），配合矩阵换算，实现了像素级的碰撞检测。

## 🎯 路线图 (Roadmap)

- [x] 核心物理引擎与流态 UI 实现
- [x] 抖动模式下的卸载逻辑与性能优化
- [x] 本地 JSON 布局记忆与动态同步
- [ ] **防误触机制调优 (Current Focus)**
- [ ] 支持多显示器独立唤醒与缩放适配
- [ ] 键盘方向键/Tab 焦点导航支持 (Accessibility)

## 🤝 参与贡献 (Contributing)

发现 Bug？有更好的动画调优方案？欢迎提交 Issue 或 PR！
在提交 PR 前，请确保您的代码没有破坏现有的坐标引擎逻辑。

## 📄 许可协议 (License)

本项目采用 [MIT License](LICENSE) 开源协议。

*Designed & Handcrafted with ❤️ in 2026*



