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
                .onContinueUserActivity("com.soloist.handoff.playback", perform: handleHandoff)
        }
        // 生命周期安全锁（退到后台强制断开服务器）
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                webDAVService.stopServer()
            }
        }
    }
    
    // MARK: - Handoff Hydration Logic
    
    private func handleHandoff(_ userActivity: NSUserActivity) {
        guard let userInfo = userActivity.userInfo,
              let songID = userInfo["songID"] as? String,
              let targetTime = userInfo["currentTime"] as? TimeInterval else {
            print("❌ [Handoff] 解析 Payload 失败")
            return
        }
        
        guard let targetSong = localLibrary.songDictionary[songID] else {
            print("❌ [Handoff] 本地曲库未找到歌曲: \(songID)")
            return
        }
        
        // 1. 提取上下文状态
        let isShuffle = userInfo["isShuffleMode"] as? Bool ?? false
        let isLoop = userInfo["isLoopMode"] as? Bool ?? false
        let windowIDs = userInfo["windowIDs"] as? [String] ?? [songID]
        
        print("🔗 [Handoff] 接管请求 | 目标: \(targetSong.title) | 模式: 随机(\(isShuffle)) 循环(\(isLoop))")
        
        // 2. 状态强覆盖（仅通过 playerService 代理，避免重复赋值）
        playerService.isShuffleMode = isShuffle
        playerService.isLoopMode = isLoop
        
        // 3. 构建物理内存队列 (将手机传来的 ID 数组映射回 Mac 本地的 Song 对象)
        var reconstructedQueue: [Song] = []
        for id in windowIDs {
            if let song = localLibrary.songDictionary[id] {
                reconstructedQueue.append(song)
            }
        }
        
        // 4. 底层队列手术级替换 (规避 play 方法的二次洗牌 Bug)
        if isShuffle {
            playerService.queueManager.updateShuffledList(reconstructedQueue)
            // 备份一份到 original，防止关闭随机时列表被清空
            playerService.queueManager.updateOriginalList(reconstructedQueue)
        } else {
            playerService.queueManager.updateOriginalList(reconstructedQueue)
            playerService.queueManager.updateShuffledList([]) // 清空旧随机列表
        }
        
        // 5. 引擎调度
        if playerService.currentSong?.id == targetSong.id {
            playerService.seek(to: targetTime)
            if !playerService.isPlaying { playerService.resume() }
        } else {
            // 注意：这里故意不传 playlist 参数，阻止其内部触发 reshuffle
            playerService.play(song: targetSong)
            playerService.seek(to: targetTime)
        }
    }
}
