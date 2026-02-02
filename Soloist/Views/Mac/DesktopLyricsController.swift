//
//  DesktopLyricsController.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import SwiftUI
import AppKit
import Combine

/// 桌面歌词控制器 (DesktopLyricsController)
///
/// **职责**: 管理桌面悬浮歌词窗口的生命周期、层级和显示状态。
/// **层级**: UI Controller (macOS AppKit)。
///
/// **核心特性**:
/// 1. **系统置顶**: 使用 `.floating` 层级，覆盖在普通窗口之上。
/// 2. **全屏穿透**: 允许在全屏应用（如看电影、写代码）时依然显示。
/// 3. **无干扰模式**: 窗口本身不获取焦点，不会打断用户当前的键盘输入。
/// 4. **屏幕自适应**: 根据当前主屏幕宽度自动调整歌词窗口大小。
class DesktopLyricsController: NSObject, ObservableObject {
    
    /// 全局单例
    static let shared = DesktopLyricsController()
    
    // MARK: - Private Properties
    
    /// 悬浮窗口实例
    private var lyricsPanel: NSPanel?
    
    /// 播放服务引用 (数据源)
    private var playerService: AudioPlayerService?
    
    /// 视图控制器引用 (防止被过早释放)
    private var hostingController: NSViewController?
    
    // 当前显示状态
        @Published var isShow: Bool = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// 切换显示/隐藏状态
    ///
    /// 这是外部调用的唯一入口。
    func toggle() {
        // 1. 如果面板尚未创建，且服务已连接，则进行初始化
        if lyricsPanel == nil && playerService != nil {
                    createPanel()
                }
        
        // 2. 只有在初始化成功后才执行显示逻辑
        guard let panel = lyricsPanel else {
            // 如果走到这里，说明 setup(with:) 还没被调用过，或者服务未连接
            // 在 SoloistApp 中，我们通常在 toggle 前已经确保 shared 实例存在
            // 如果你是懒加载策略，这里会自动尝试初始化
            if let service = AudioPlayerService.shared as AudioPlayerService? {
               self.playerService = service
               createPanel()
               // 递归调用一次，或者直接显示
               lyricsPanel?.orderFront(nil)
            }
            return
        }
        
        // 3. 切换可见性
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            // 每次显示时重新校准位置 (防止用户切换了分辨率)
            repositionPanel()
            panel.orderFront(nil)
        }
        self.isShow = panel.isVisible
    }
    
    /// 初始化配置
    ///
    /// 通常在 App 启动时调用，或者第一次打开歌词时懒加载调用。
    func setup(with service: AudioPlayerService) {
        self.playerService = service
        // 此时不立即创建窗口，等到用户点击 toggle 时再创建 (Lazy Load)
    }
    
    // MARK: - Internal Setup
    
    private func createPanel() {
        guard let playerService = playerService else { return }
        
        // 1. 计算窗口尺寸
        // 获取主屏幕，如果获取失败则使用第一个屏幕
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenWidth = screen.visibleFrame.width
        
        // 设定宽度为屏幕宽度的 60%，高度固定 100pt
        // 这样既能容纳长歌词，又不会遮挡太多内容
        let panelWidth: CGFloat = screenWidth * 0.6
        let panelHeight: CGFloat = 100
        
        // 2. 创建 NSPanel (比 NSWindow 更适合做辅助窗口)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            // .nonactivatingPanel: 关键样式，确保点击窗口时不会激活 App，不抢键盘焦点
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 3. 配置窗口行为
        panel.level = .floating // 悬浮层级
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 允许在全屏空间显示
        panel.backgroundColor = .clear // 透明背景
        panel.isOpaque = false
        panel.hasShadow = false
        
        // 允许鼠标交互 (设为 true 则鼠标穿透，无法拖拽；设为 false 则可以接收点击)
        panel.ignoresMouseEvents = false
        // 允许按住背景拖拽移动
        panel.isMovableByWindowBackground = true
        
        // 4. 绑定 SwiftUI 视图
        let lyricsView = DesktopLyricsView(playerService: playerService)
        
        // 使用 NSHostingController 桥接
        let rootView = lyricsView.frame(width: panelWidth, height: panelHeight)
        let hostingController = NSHostingController(rootView: rootView)
        
        // 确保 Hosting View 背景也是透明的
        hostingController.view.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingController.view.autoresizingMask = [.width, .height]
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentViewController = hostingController
        self.hostingController = hostingController
        self.lyricsPanel = panel
        
        // 5. 设置初始位置
        repositionPanel()
    }
    
    /// 将窗口重新放置到屏幕底部居中
    private func repositionPanel() {
        guard let panel = lyricsPanel, let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let panelWidth = panel.frame.width
        
        // X轴居中
        let x = screenRect.minX + (screenRect.width - panelWidth) / 2
        // Y轴固定在底部上方 100pt 处
        let y = screenRect.minY + 100
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
