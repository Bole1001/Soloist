//
//  SystemMediaHandler.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import Foundation
import MediaPlayer

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class SystemMediaHandler {
    // 持有主服务的弱引用，避免循环引用
    private weak var playerService: AudioPlayerService?
    
    init(service: AudioPlayerService) {
        self.playerService = service
        setupRemoteCommandCenter()
    }
    
    // MARK: - 1. 处理系统控制指令 (耳机/控制中心 -> App)
    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        
        // 清除旧的 Target (防止重复绑定)
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        
        // 绑定新指令
        center.playCommand.addTarget { [weak self] _ in
            self?.playerService?.resume()
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            self?.playerService?.pause()
            return .success
        }
        
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playerService?.next()
            return .success
        }
        
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playerService?.previous()
            return .success
        }
        
        // 进度拖拽
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let service = self.playerService else { return .commandFailed }
            
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                // 调用 Service 新暴露的 seek 方法
                service.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - 2. 更新系统显示信息 (App -> 锁屏/动态岛)
    func updateNowPlayingInfo(song: Song?, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        guard let song = song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        // 基础信息
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // 异步加载封面
        Task {
            if let data = await ArtworkLoader.loadArtwork(for: song) {
                let artwork = createArtwork(from: data)
                if let artwork = artwork {
                    // 获取最新的 info (防止并发覆盖)
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }
        }
    }
    
    // 封装跨平台的图片转换逻辑
    private func createArtwork(from data: Data) -> MPMediaItemArtwork? {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
        #else
        guard let image = UIImage(data: data) else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
        #endif
    }
}
