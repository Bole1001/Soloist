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

- [x] **iOS-6.1** 评估 `AudioPlayerService.shared` 单例的必要性
  - 文件：`Soloist/Core/Services/AudioPlayerService.swift`
  - 具体：保留为 App 级唯一播放协调器，供主界面、系统媒体中心和快捷指令共用

- [x] **iOS-6.2** 评估 `UserPlaylistManager` / `LocalLibraryService` 是否需要全局共享
  - 文件：`Soloist/Core/Services/UserPlaylistManager.swift`、`Soloist/Core/Services/LocalLibraryService.swift`
  - 具体：由 `SoloistApp` 统一持有并注入视图层，不改成全局共享单例

- [x] **macOS-6.3** 评估 `PhantomGuard.shared` / `MenuBarManager.shared` / `LyricsWindowManager.shared`
  - 文件：`SoloistMac/Core/PhantomGuard.swift`、`SoloistMac/UI/MenuBar/MenuBarManager.swift`、`SoloistMac/UI/Windows/LyricsWindowManager.swift`
  - 具体：明确生命周期，避免跨界面污染

- [x] **cross-6.4** 收敛重复的全局状态源
  - 具体：避免同一状态在多个对象里各自维护

## 第 7 阶段：macOS 菜单栏播放控制

- [x] **macOS-7.1** 评估菜单栏展示当前歌曲信息的入口
  - 文件：`SoloistMac/UI/MenuBar/MenuBarManager.swift`、`SoloistMac/Core/PhantomGuard.swift`
  - 具体：菜单顶部显示当前歌曲名，必要时附带歌手或播放状态

- [x] **macOS-7.2** 评估菜单栏控制 Apple Music 的动作入口
  - 文件：`SoloistMac/Services/MusicController.swift`、`SoloistMac/Core/PhantomGuard.swift`
  - 具体：补齐播放/暂停、下一首、上一首的控制接口，并确保失败可降级

- [x] **macOS-7.3** 把菜单项事件回调接到 `PhantomGuard`
  - 文件：`SoloistMac/UI/MenuBar/MenuBarManager.swift`、`SoloistMac/Core/PhantomGuard.swift`
  - 具体：通过统一协调器处理点击事件，避免菜单栏直接操作业务状态

- [x] **macOS-7.4** 让菜单状态与 Apple Music 状态保持同步
  - 文件：`SoloistMac/Services/MusicMonitor.swift`、`SoloistMac/Core/PhantomGuard.swift`
  - 具体：切歌、暂停、恢复播放时同步更新菜单标题与可用状态

- [x] **macOS-7.5** 验证菜单栏交互的失败降级路径
  - 文件：`SoloistMac/Services/MusicController.swift`、`SoloistMac/Core/PhantomGuard.swift`
  - 具体：Apple Music 未运行、无权限、桥接不可用时给出可恢复提示，不阻塞主流程

## 当前判断

- 这个需求可行，且复用现有 `MusicMonitor` + `PhantomGuard` 的成本较低
- 菜单顶部已有展示位，适合显示当前歌曲名
- 需要新增的主要能力在 `MusicController`，尤其是播放控制动作
- 推荐实现顺序：
  1. 先补 `MusicController` 的控制接口
  2. 再接入 `MenuBarManager` 的菜单项和标题显示
  3. 最后由 `PhantomGuard` 统一同步状态和失败降级
- 代码层已完成，`xcodebuild` 这台环境目前无法正确识别仓库里的 workspace 入口，构建验证受限于环境而不是这次改动
