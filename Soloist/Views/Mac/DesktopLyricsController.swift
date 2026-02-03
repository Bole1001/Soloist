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
    
    // 当前显示状态 (必须是 @Published，UI 才能监听变色)
    @Published var isShow: Bool = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// 切换显示/隐藏状态
    func toggle() {
        if isShow {
            hide()
        } else {
            show()
        }
    }
    
    /// 强制显示 (供 .onAppear 调用)
    func show() {
        // 1. 确保面板已创建
        ensurePanelCreated()
        
        // 2. 显示面板
        if let panel = lyricsPanel {
            // 每次显示时重新校准位置
            repositionPanel()
            panel.orderFront(nil)
            
            // 3. 更新状态
            self.isShow = true
        }
    }
    
    /// 强制隐藏
    func hide() {
        lyricsPanel?.orderOut(nil)
        self.isShow = false
    }
    
    /// 初始化配置 (懒加载)
    func setup(with service: AudioPlayerService) {
        self.playerService = service
    }
    
    // MARK: - Private Helpers
    
    /// 确保面板已创建 (懒加载逻辑的核心)
    private func ensurePanelCreated() {
        // 如果面板已存在，直接返回
        if lyricsPanel != nil { return }
        
        // 如果 service 为空，尝试自动获取单例
        if playerService == nil {
            self.playerService = AudioPlayerService.shared
        }
        
        // 创建面板
        createPanel()
    }
    
    private func createPanel() {
        guard let playerService = playerService else { return }
        
        // 1. 计算窗口尺寸
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenWidth = screen.visibleFrame.width
        
        let panelWidth: CGFloat = screenWidth * 0.6
        let panelHeight: CGFloat = 100
        
        // 2. 创建 NSPanel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel], // 关键：不抢焦点
            backing: .buffered,
            defer: false
        )
        
        // 3. 配置窗口行为
        panel.level = .floating // 悬浮最上层
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // 允许全屏覆盖
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        
        // 4. 绑定 SwiftUI 视图
        // ⚠️ 确保你有 DesktopLyricsView 这个视图文件
        let lyricsView = DesktopLyricsView(playerService: playerService)
        
        let rootView = lyricsView.frame(width: panelWidth, height: panelHeight)
        let hostingController = NSHostingController(rootView: rootView)
        
        // 透明背景修正
        hostingController.view.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        hostingController.view.autoresizingMask = [.width, .height]
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentViewController = hostingController
        
        self.hostingController = hostingController
        self.lyricsPanel = panel
        
        // 5. 设置初始位置
        repositionPanel()
    }
    
    private func repositionPanel() {
        guard let panel = lyricsPanel, let screen = NSScreen.main else { return }
        
        let screenRect = screen.visibleFrame
        let panelWidth = panel.frame.width
        
        let x = screenRect.minX + (screenRect.width - panelWidth) / 2
        // Y轴固定在底部上方 100pt
        let y = screenRect.minY + 100
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
