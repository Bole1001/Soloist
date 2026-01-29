//
//  DesktopLyricsController.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import SwiftUI
import AppKit
import Combine

class DesktopLyricsController: NSObject, ObservableObject {
    static let shared = DesktopLyricsController()
    
    private var lyricsPanel: NSPanel?
    var playerService: AudioPlayerService?
    
    // 使用通用的 NSViewController 类型
    private var hostingController: NSViewController?
    
    private override init() {
        super.init()
    }
    
    func setup(with service: AudioPlayerService) {
        self.playerService = service
        if lyricsPanel == nil {
            createPanel()
        }
    }
    
    private func createPanel() {
        guard let playerService = playerService else { return }
        
        // 1. 创建面板
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 2. 关键设置
        panel.level = .floating // 永远置顶
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        
        // ✨ 关键修改 A：关闭鼠标穿透
        // 必须设为 false，否则鼠标点击会直接穿过窗口，导致无法拖动
        panel.ignoresMouseEvents = false
        
        // ✨ 关键修改 B：允许通过背景拖动窗口
        // 这样你按住歌词或周围的透明区域，就可以把窗口拖走
        panel.isMovableByWindowBackground = true
        
        // 3. 绑定视图
        let lyricsView = DesktopLyricsView(playerService: playerService)
        // 强制固定大小
        let rootView = lyricsView.frame(width: 800, height: 120)
        let hostingView = NSHostingController(rootView: rootView)
        
        // 确保 SwiftUI 视图背景透明
        hostingView.view.frame = NSRect(x: 0, y: 0, width: 800, height: 120)
        hostingView.view.autoresizingMask = [.width, .height]
        hostingView.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentViewController = hostingView
        self.hostingController = hostingView
        
        // 4. 初始位置 (屏幕底部偏上)
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.minX + (screenRect.width - 800) / 2
            let y = screenRect.minY + 120
            
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.lyricsPanel = panel
    }
    
    func toggle() {
        guard let panel = lyricsPanel else {
            if let service = playerService { setup(with: service) }
            return
        }
        
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
        }
    }
}
