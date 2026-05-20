//
//  SoloistApp.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

@main
struct SoloistApp: App {
    
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
        WindowGroup {
            IphoneHomeView()
                .environmentObject(playerService)
                .environmentObject(webDAVService)
                .environmentObject(userPlaylistManager)
                .environmentObject(playerService.queueManager)
                .environmentObject(localLibrary)
                // .onContinueUserActivity("com.soloist.handoff.playback", perform: handleHandoff) // Handoff disabled
        }
        // 生命周期管理：后台停止服务器并刷新歌曲列表
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                webDAVService.stopServer()
                localLibrary.refreshLibrary()
            case .active:
                webDAVService.startServer()
            default:
                break
            }
        }
    }
}
