# Soloist

> 专为 macOS, iOS & watchOS 打造的沉浸式本地音乐播放器。
> A native, immersive local music player.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20watchOS-lightgrey.svg?style=flat-square)

## ✨ 简介 (Introduction)

**Soloist** 是一款回归音乐本质的播放器，专注于管理和播放本地高品质音乐库。

项目完全基于 **SwiftUI** 构建，采用 **Single Target, Multi-Destination** 架构实现了 macOS、iOS 与 watchOS 的代码共享。针对 macOS 端，Soloist 利用 **AppKit** 与 **Metal** 技术实现了深度原生体验，包括实时高斯模糊背景、桌面级悬浮歌词以及 Touch Bar 支持。

## 📂 资源准备 (Resources)

**Soloist** 是一款纯粹的本地播放器，应用内不包含任何音乐版权资源。

* **音频文件**: 请自行准备 `.mp3` 格式的高品质音乐文件。
* **歌词同步**: 如需显示歌词，请准备对应的 `.lrc` 文件，并确保其**文件名与音频文件完全一致**，且存放在**同一文件夹**内的**Lyrics**文件夹中。

> **示例**：
> Music/
> ├── Hello.mp3
> └── Lyrics/Hello.lrc

## 📸 预览 (Screenshots)



*(注：iOS 及 watchOS 版本正在积极开发中)*

## 🚀 核心功能 (Features)

### 🖥️ macOS 端体验
* **沉浸式视觉**: 基于 Metal (`drawingGroup`) 加速的动态模糊背景，随封面色调实时流转，极低 GPU 占用。
* **桌面悬浮歌词**: 独立的悬浮窗组件。
* **原生交互集成**:
    * **Touch Bar**: 在 MacBook Pro 触控栏上显示实时歌词。
    * **Menu Bar Extra**: 常驻菜单栏。

### 📱 iOS 端 (开发中)
* **移动端适配**: 针对触控操作优化的 UI 布局与手势交互。
* **共享内核**: 与 Mac 端共用核心播放逻辑。

### ⌚️ watchOS 端 (计划中)
* **腕上控制**: 独立的播放控制与简单的库浏览。

## 📅 开发计划 (Roadmap)

- [x] **macOS端**开发
- [ ] **iOS 端 APP 开发** (进行中)
- [ ] iOS 文件导入
- [ ] **watchOS 端 APP 开发**
- [ ] 播放列表管理 (创建/编辑)
- [ ] 均衡器 (EQ) 支持
- [ ] iCloud 同步 (播放进度/收藏)

## 🛠 技术栈 (Tech Stack)

* **UI 框架**: SwiftUI 
* **音频核心**: AVFoundation
* **平台适配**: AppKit (macOS) / UIKit (iOS) 混编适配层
* **并发编程**: Swift Concurrency (Async/Await)

## 📥 下载与安装 (Installation)

> ⚠️ **注意**：由于未加入 Apple 开发者计划，首次打开可能会提示“已损坏”或“无法验证开发者”。

### iOS / watchOS 用户 

由于本项目未发布至 App Store，iOS 和 watchOS 版本需要通过 Xcode **自行编译安装 (Build from source)**： 

1. 克隆本项目代码。
2. 使用 Xcode 打开项目。
3. 连接你的 iPhone / Apple Watch。
4. 选择对应的 Target (iOS/watchOS) 并运行。 *(推荐使用免费的 Apple ID 进行真机调试，有效期之后重新安装)*

