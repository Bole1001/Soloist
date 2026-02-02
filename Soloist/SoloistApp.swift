//
//  SoloistApp.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct SoloistApp: App {
    
    // MARK: - State Management
    
    /// 全局唯一的播放服务实例 (Single Source of Truth)
    /// 所有视图通过此对象监听播放状态变化
    @StateObject private var playerService = AudioPlayerService.shared
    
    // MARK: - Environment
    
    #if os(macOS)
    /// 仅 macOS: 用于编程式打开窗口的环境变量
    @Environment(\.openWindow) var openWindow
    #endif
    
    var body: some Scene {
        
        // MARK: - macOS Scene Configuration
        #if os(macOS)
        
        // 1. 主应用程序窗口
        Window("Soloist", id: "MainWindow") {
            MacHomeView()
                // 应用毛玻璃背景特效，并忽略安全区域以铺满窗口
                .background(VisualEffect().ignoresSafeArea())
        }
        // 隐藏默认标题栏，实现沉浸式设计
        .windowStyle(.hiddenTitleBar)
        .commands {
            // 移除或替换系统默认菜单项，保持菜单栏清爽
            CommandGroup(replacing: .newItem) { }
        }
        
        // 2. 菜单栏驻留图标 (Menu Bar Extra)
        // 注意：需确保 Assets 中名为 "MenuBarIcon" 的图片 Render As 设置为 Template Image
        MenuBarExtra("Soloist", image: "MenuBarIcon") {
            
            // MARK: Navigation
            Button("显示主界面") {
                // 强制将应用前置，防止窗口被其他应用遮挡
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "MainWindow")
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            // MARK: Feature Toggles
            // 仅在私有 API 可用时显示触控栏选项
            if TouchBarManager.shared.isFeatureAvailable {
                Button("开启触控栏歌词") {
                    TouchBarManager.shared.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            
            // MARK: Player Controls
            // 实时显示当前播放曲目
            Text(playerService.currentSong?.title ?? "Soloist")
                .font(.caption)
            
            Button("播放/暂停") {
                playerService.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: []) // 仅当菜单展开时生效
            
            Button("上一首") {
                playerService.previous()
            }
            
            Button("下一首") {
                playerService.next()
            }
            
            Divider()
            
            // MARK: System Features
            Button("桌面悬浮歌词") {
                DesktopLyricsController.shared.toggle()
            }
            
            Divider()
            
            // MARK: App Lifecycle
            Button("退出 Soloist") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
        
        // MARK: - iOS Scene Configuration
        #else
        
        WindowGroup {
            // iOS 入口占位
            if #available(iOS 16.0, *) {
                Text("iOS 端主页开发中...")
            } else {
                Text("iOS 端主页开发中...")
            }
        }
        
        #endif
    }
}

// MARK: - Helper Views (macOS)

#if os(macOS)
/// NSVisualEffectView 的 SwiftUI 封装
///
/// 用于实现 macOS 原生的毛玻璃 (Blur) 和半透明效果。
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow // 混合模式：背景模糊
        view.state = .active              // 激活状态：始终保持模糊，即使窗口未激活
        view.material = .sidebar          // 材质：使用侧边栏磨砂材质
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 静态视图，无需动态更新
    }
}
#endif
