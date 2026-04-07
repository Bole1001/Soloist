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
    
    // MARK: - App Delegate Integration
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // MARK: - State Management
    
    @StateObject private var playerService = AudioPlayerService.shared
    
    @StateObject private var userPlaylistManager = UserPlaylistManager()
    
    @StateObject private var localLibrary = LocalLibraryService()
    
    // WebDAV 服务状态（仅限 iOS）
    #if os(iOS)
    @StateObject private var webDAVService = WebDAVService()
    @Environment(\.scenePhase) private var scenePhase
    #endif
    
    var body: some Scene {
        
        // MARK: - macOS Scene Configuration
        #if os(macOS)
        
        Window("Soloist", id: "MainWindow") {
            MacHomeView()
                .background(VisualEffect().ignoresSafeArea())
                .environmentObject(playerService)
                .environmentObject(userPlaylistManager)
                .environmentObject(playerService.queueManager)
                .environmentObject(localLibrary)
                .onReceive(NotificationCenter.default.publisher(for: .handoffDidArrive)) { notification in
                    if let activity = notification.object as? NSUserActivity {
                        handleHandoff(activity)
                    }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        // MARK: - iOS Scene Configuration
        #else
        
        WindowGroup {
            IphoneHomeView()
                .environmentObject(playerService)
                .environmentObject(webDAVService)
                .environmentObject(userPlaylistManager)
                .environmentObject(playerService.queueManager)
                .environmentObject(localLibrary)
                .onContinueUserActivity("com.soloist.handoff.playback", perform: handleHandoff)
        }
        // 生命周期安全锁（退到后台强制断开服务器）
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                webDAVService.stopServer()
            }
        }
        
        #endif
    }
    
    // MARK: - Handoff Hydration Logic
    
    /// 统一的数据水合与状态还原处理器
    private func handleHandoff(_ userActivity: NSUserActivity) {
        // 1. 拆解 Payload 数据包
        guard let userInfo = userActivity.userInfo,
              let songID = userInfo["songID"] as? String,
              let targetTime = userInfo["currentTime"] as? TimeInterval else {
            print("❌ [Handoff] 解析 Payload 失败或数据不完整")
            return
        }
        
        print("🔗 [Handoff] 收到接力请求，目标歌曲 ID: \(songID)，进度: \(targetTime)s")
        
        // 2. 内存字典 O(1) 极速水合查询
        // 依赖 localLibrary 初始化时已经从缓存同步加载完毕
        guard let targetSong = localLibrary.songDictionary[songID] else {
            print("❌ [Handoff] 失败：接收端本地曲库未找到对应的歌曲实体。请检查两端文件是否对齐。")
            return
        }
        
        // 3. 执行接力播放引擎调度
        if playerService.currentSong?.id == targetSong.id {
            // 如果两边正在放同一首歌，只同步进度
            playerService.seek(to: targetTime)
            if !playerService.isPlaying { playerService.resume() }
        } else {
            // 切歌并带参拉起进度
            playerService.play(song: targetSong)
            
            // 必须进行微小延迟，确保底层的 AVAudioEngine 节点缓冲建立完成，再执行精准定位
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                playerService.seek(to: targetTime)
            }
        }
    }
}

// MARK: - Helper Views (macOS)
#if os(macOS)
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
#endif
