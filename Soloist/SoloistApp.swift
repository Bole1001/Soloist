//
//  SoloistApp.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

@main
struct SoloistApp: App {
    @StateObject private var playerService = AudioPlayerService.shared
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        // --- 1. 主窗口 ---
        WindowGroup(id: "MainWindow") {
            MacHomeView()
                .background(VisualEffect().ignoresSafeArea())
        }
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: Set(arrayLiteral: "MainWindow"))
        
        // --- 2. 菜单栏 (功能增强版) ---
        MenuBarExtra("Soloist", image: "MenuBarIcon") {
            
            // --- 第一组：核心动作 ---
            Button("显示主界面") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "MainWindow")
            }
            .keyboardShortcut("o", modifiers: .command) // Cmd+O 快捷键
            
            Divider()
            
            // --- 第二组：播放控制 (在菜单里直接能看到歌名) ---
            Text(playerService.currentSong?.title ?? "未播放")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("上一首") { playerService.previous() }
                
                Button(playerService.isPlaying ? "暂停" : "播放") {
                    playerService.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: []) // 空格键播放/暂停 (当菜单打开时)
                
                Button("下一首") { playerService.next() }
            }
            
            Divider()
            
            // --- 第三组：系统操作 ---
            Button("桌面歌词") {
                DesktopLyricsController.shared.toggle()
            }
            
            Divider()
            
            Button("退出 Soloist") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

// VisualEffect 保持不变
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}
