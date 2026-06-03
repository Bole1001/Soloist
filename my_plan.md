# Soloist 重构 TODO 清单

## 第 1 阶段：iOS 核心播放稳定性修复

- [x] **iOS-1.1** 重构 `AudioPlayerService`：移除强制解包风险
  - 文件：`Soloist/Core/Services/AudioPlayerService.swift`
  - 具体：清理播放结束回调中的 `self!` / `currentSong!` 依赖

- [x] **iOS-1.2** 修复异步状态竞争：将播放进度和歌词更新收敛到主线程
  - 文件：`Soloist/Core/Services/AudioPlayerService.swift`
  - 具体：确保 `currentTime`、`currentLyric`、`lyrics` 的更新都在主线程执行

- [x] **iOS-1.3** 移除播放链路中的延迟依赖
  - 文件：`Soloist/SoloistApp.swift`、`Soloist/Core/Services/AudioPlayerService.swift`
  - 具体：不再依赖 `DispatchQueue.main.asyncAfter` 处理播放状态、歌词加载或接管流程

- [x] **iOS-1.4** 统一 `isShuffleMode` / `isLoopMode` 状态来源
  - 文件：`Soloist/Core/Services/AudioPlayerService.swift`
  - 具体：保证 `playerService` 与 `queueManager` 的模式状态始终一致

- [x] **iOS-1.5** 补齐 `SoloistApp` 生命周期闭环
  - 文件：`Soloist/SoloistApp.swift`
  - 具体：在 `scenePhase == .active` 时自动恢复 `webDAVService.startServer()`
  - 已完成：后台时停止 `WebDAV`、刷新媒体库

## 第 1.5 阶段：iOS 端补漏项

- [x] **iOS-1.6** 接通本地文件夹权限恢复流程
  - 文件：`Soloist/Core/Services/LocalLibraryService.swift`、`Soloist/Views/IOS/SettingsPage.swift`
  - 具体：让 `scanAndSavePermission()` / `restorePermission()` 真正进入启动和设置流程
  - 目标：避免用户重启后权限已保存但功能没有恢复

- [x] **iOS-1.7** 清理歌词页残留的延迟刷新
  - 文件：`Soloist/Views/IOS/LyricsFullView.swift`、`Soloist/Views/Shared/ScrollingLyricsView.swift`
  - 具体：移除 `DispatchQueue.main.asyncAfter`，改成确定性的首次滚动和拖动回弹机制

- [x] **iOS-1.8** 避免主页 `onAppear` 触发无条件全量扫描
  - 文件：`Soloist/Views/IOS/IphoneHomeView.swift`
  - 具体：把 `loadLocalDocuments()` 改为显式刷新、首次启动扫描或可控的 debounce 刷新

- [x] **iOS-1.9** 加固 LRC 解析器边界处理
  - 文件：`Soloist/Core/Services/LRCParser.swift`、`SoloistMac/Services/LRCParser.swift`
  - 具体：去掉 `try!` 和过强的最后匹配假设，对空行、异常时间戳和坏编码保持可恢复

## 第 2 阶段：macOS Apple Music 同步稳定性修复

- [x] **macOS-2.1** 改进 `MusicMonitor` 通知处理
  - 文件：`SoloistMac/Services/MusicMonitor.swift`
  - 具体：减少对字符串值的依赖，补充字段缺失、格式异常、重复通知的处理

- [x] **macOS-2.2** 完善 `MusicController` 权限与失败处理
  - 文件：`SoloistMac/Services/MusicController.swift`
  - 具体：补充 Apple Music 未运行、无权限、`SBApplication` 不可用时的降级流程

- [x] **macOS-2.3** 优化 `PhantomGuard` 定时器机制
  - 文件：`SoloistMac/Core/PhantomGuard.swift`
  - 具体：改进 `displayTimer` 和 `syncCounter`，减少手动时间漂移校准依赖

- [x] **macOS-2.4** 拆分 `PhantomGuard` UI 职责
  - 文件：`SoloistMac/Core/PhantomGuard.swift`、`SoloistMac/UI/MenuBar/MenuBarManager.swift`、`SoloistMac/UI/Windows/LyricsWindowManager.swift`
  - 具体：让状态同步、菜单栏、悬浮窗各自收敛到明确边界

- [x] **macOS-2.5** 清理 macOS 启动/唤醒中的延迟依赖
  - 文件：`SoloistMac/Core/PhantomGuard.swift`
  - 具体：去掉 `refreshUIComponents()` 里的固定延迟唤醒，改为窗口和菜单真正可用后的确定性展示

- [x] **macOS-2.6** 统一 macOS 事件监听生命周期
  - 文件：`SoloistMac/Services/MusicMonitor.swift`、`SoloistMac/Core/PhantomGuard.swift`
  - 具体：避免重复注册、未使用回调和生命周期散落在多个对象里

## 第 3 阶段：两端错误处理与恢复

- [x] **iOS-3.1** 让 `LibraryPersistenceService` 返回可处理的错误
  - 文件：`Soloist/Core/Services/LibraryPersistenceService.swift`
  - 具体：将 `print` 替换为 `Result<T, Error>`、回调或等价的错误通道

- [x] **iOS-3.2** 让 `LocalLibraryService` 对失败可回传错误
  - 文件：`Soloist/Core/Services/LocalLibraryService.swift`
  - 具体：权限失败、删除失败、导入失败时统一返回错误

- [x] **iOS-3.3** 让 `LyricsFetcher` 的网络失败和解析失败可回调到 UI
  - 文件：`Soloist/Core/Services/LyricsFetcher.swift`
  - 具体：网络请求失败、数据解析失败时提供统一回调

- [x] **iOS-3.4** 让 `WebDAVService` 的启动失败、绑定失败、上传失败可见化
  - 文件：`Soloist/Core/Services/WebDAVService.swift`
  - 具体：把错误传递到设置页或状态层，而不是只打印日志

- [x] **iOS-3.5** 统一 LRC 读取失败的降级策略
  - 文件：`Soloist/Core/Services/LyricsManager.swift`、`Soloist/Core/Services/LRCParser.swift`
  - 具体：本地 `.lrc`、内嵌歌词、网络歌词都要有明确失败出口

- [x] **macOS-3.6** 为 `LyricEngine` 和 `MusicController` 增加失败恢复
  - 文件：`SoloistMac/Services/LyricEngine.swift`、`SoloistMac/Services/MusicController.swift`
  - 具体：Apple Music 离线、权限拒绝、歌词缺失时保持 UI 可用

## 第 4 阶段：iOS 生命周期与服务管理完善

- [x] **iOS-4.1** 补齐 `SoloistApp` 的完整 `scenePhase` 处理
  - 文件：`Soloist/SoloistApp.swift`
  - 具体：前台、活跃、后台、暂停各阶段的服务启停逻辑

- [x] **iOS-4.2** 明确 `LocalLibraryService` 的初始化、恢复和销毁边界
  - 文件：`Soloist/Core/Services/LocalLibraryService.swift`
  - 具体：明确权限恢复、首次扫描、后台刷新和资源释放边界

- [x] **iOS-4.3** 明确 `UserPlaylistManager` 的生命周期和持久化边界
  - 文件：`Soloist/Core/Services/UserPlaylistManager.swift`
  - 具体：明确保存时机、观察者注册与注销边界

- [x] **iOS-4.4** 明确权限恢复与库扫描的启动顺序
  - 文件：`Soloist/Core/Services/LocalLibraryService.swift`、`Soloist/SoloistApp.swift`
  - 具体：先恢复权限，再决定是否扫描或刷新，避免无权限状态下空转

- [x] **iOS-4.5** 统一设置页里的导入、刷新、启动服务入口
  - 文件：`Soloist/Views/IOS/SettingsPage.swift`
  - 具体：避免“有按钮但启动链路不一致”的情况

## 第 5 阶段：macOS UI 与业务分离

- [x] **macOS-5.1** 让 `MenuBarManager` 只负责菜单栏 UI
  - 文件：`SoloistMac/UI/MenuBar/MenuBarManager.swift`
  - 具体：只保留挂载、显示、更新，不承载状态同步核心逻辑

- [x] **macOS-5.2** 让 `LyricsWindowManager` 只负责悬浮窗 UI
  - 文件：`SoloistMac/UI/Windows/LyricsWindowManager.swift`
  - 具体：只保留显示、隐藏、锁定和鼠标穿透行为

- [x] **macOS-5.3** 明确 `AppDelegate` 和 `SoloistMacApp` 的启动职责
  - 文件：`SoloistMac/App/AppDelegate.swift`、`SoloistMac/App/SoloistMacApp.swift`
  - 具体：入口清晰，启动流程明确，避免逻辑混乱

- [x] **macOS-5.4** 收敛 `PhantomGuard` 的状态同步职责
  - 文件：`SoloistMac/Core/PhantomGuard.swift`
  - 具体：不再同时承担 UI 挂载、歌词渲染、定时同步、终止处理

## 第 6 阶段：依赖控制与单例管理

- [ ] **iOS-6.1** 评估 `AudioPlayerService.shared` 单例的必要性
  - 文件：`Soloist/Core/Services/AudioPlayerService.swift`
  - 具体：考虑改为 `@StateObject` 或依赖注入

- [ ] **iOS-6.2** 评估 `UserPlaylistManager` / `LocalLibraryService` 是否需要全局共享
  - 文件：`Soloist/Core/Services/UserPlaylistManager.swift`、`Soloist/Core/Services/LocalLibraryService.swift`
  - 具体：明确是否必须全局共享或可转为组件局部

- [x] **macOS-6.3** 评估 `PhantomGuard.shared` / `MenuBarManager.shared` / `LyricsWindowManager.shared`
  - 文件：`SoloistMac/Core/PhantomGuard.swift`、`SoloistMac/UI/MenuBar/MenuBarManager.swift`、`SoloistMac/UI/Windows/LyricsWindowManager.swift`
  - 具体：明确生命周期，避免跨界面污染

- [x] **cross-6.4** 收敛重复的全局状态源
  - 具体：避免同一状态在多个对象里各自维护

## 第 7 阶段：测试与文档

- [ ] **iOS-7.1** 为 `AudioPlayerService` 编写单元测试
  - 具体：播放控制、队列管理、恢复流程的测试用例

- [ ] **iOS-7.2** 为 `PlaylistManager` 编写单元测试
  - 具体：随机、循环、队列操作的测试用例

- [ ] **iOS-7.3** 为 iOS 核心流程补架构文档
  - 具体：播放流程、权限恢复、后台刷新、WebDAV 的说明

- [ ] **macOS-7.4** 为 `MusicMonitor` / `MusicController` 编写单元测试
  - 具体：通知监听、权限处理、失败恢复的测试用例

- [ ] **macOS-7.5** 为 `LyricEngine` 编写单元测试
  - 具体：歌词加载、路径解析、行号查找的测试用例

- [ ] **macOS-7.6** 为 macOS 核心流程补架构文档
  - 具体：Apple Music 监听、歌词同步、UI 显示的说明

## 第 8 阶段：项目隔离验证

- [ ] **Verify-8.1** 确认 iOS 项目不依赖 macOS 项目的任何源码
  - 具体：检查 `Soloist/` 中无 `../SoloistMac/` 引用

- [ ] **Verify-8.2** 确认 macOS 项目不依赖 iOS 项目的任何源码
  - 具体：检查 `SoloistMac/` 中无 `../Soloist/` 引用

- [ ] **Verify-8.3** 确认两端不存在误共享源码
  - 具体：如 `LyricLine.swift`、`LRCParser.swift` 应在两端各自独立维护

- [ ] **Verify-8.4** 确认共享的仅为非源码文件
  - 具体：README、LICENSE、workspace 配置等可共享

---

## 优先执行顺序建议

1. 先补完 `iOS-1.5`，让第 1 阶段真正闭环
2. 再处理 iOS 端补漏项 `1.6` 到 `1.9`
3. 接着处理 macOS 同步稳定性 `2.1` 到 `2.6`
4. 然后补错误处理与恢复 `3.x`
5. 再做生命周期、职责拆分、依赖控制
6. 最后补测试、文档和项目隔离验证

## 当前判断

- 第 1 阶段不能再标记为完全完成
- `scenePhase == .active` 的 WebDAV 恢复是明确缺口
- 计划外发现的问题里，优先级最高的是：
  - iOS 权限恢复未接通
  - iOS 主页重复全量扫描
  - 残留 `asyncAfter`
  - macOS 启动/唤醒的延迟依赖
