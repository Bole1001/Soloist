//
//  SystemMediaHandler.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import Foundation
import MediaPlayer
import UIKit

/// 系统媒体管家 (SystemMediaHandler)
///
/// **职责**: 负责 App 与操作系统媒体中心 (MPRemoteCommandCenter / MPNowPlayingInfoCenter) 的双向交互。
/// **层级**: Core Layer (Service Helper)。
///
/// **功能**:
/// 1. **接收指令**: 处理来自耳机、键盘媒体键、控制中心、Apple Watch 的播放/暂停/切歌指令。
/// 2. **发送状态**: 将当前播放的歌曲信息（封面、标题、进度）推送到锁屏界面和动态岛。
class SystemMediaHandler {
    
    // MARK: - Dependencies
    
    /// 持有主播放服务的弱引用
    ///
    /// 必须使用 `weak`，因为 AudioPlayerService 持有 SystemMediaHandler，
    /// 如果这里也是强引用，会导致内存泄漏 (Retain Cycle)。
    private weak var playerService: AudioPlayerService?
    
    // MARK: - Initialization
    
    /// 初始化并注册系统指令
    /// - Parameter service: 宿主播放服务
    init(service: AudioPlayerService) {
        self.playerService = service
        
        // 立即注册指令监听
        setupRemoteCommandCenter()
    }
    
    // MARK: - Remote Commands (System -> App)
    
    /// 配置远程控制中心 (耳机/锁屏/键盘按键)
    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        
        // 1. 清理旧的 Target (防止重复绑定导致多次触发)
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        
        // 2. 绑定新指令
        // 每个闭包都必须捕获 [weak self]，防止循环引用
        
        // 播放
        center.playCommand.addTarget { [weak self] _ in
            self?.playerService?.resume()
            return .success
        }
        
        // 暂停
        center.pauseCommand.addTarget { [weak self] _ in
            self?.playerService?.pause()
            return .success
        }
        
        // 下一首
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playerService?.next()
            return .success
        }
        
        // 上一首
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playerService?.previous()
            return .success
        }
        
        // 进度条拖拽 (Scrubbing)
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let service = self.playerService else { return .commandFailed }
            
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                // 调用 Service 暴露的跳转方法
                service.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - Now Playing Info (App -> System)
    
    /// 更新系统锁屏/控制中心的媒体显示信息
    ///
    /// - Parameters:
    ///   - song: 当前歌曲
    ///   - isPlaying: 播放状态
    ///   - currentTime: 当前进度
    ///   - duration: 总时长
    func updateNowPlayingInfo(song: Song?, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        // 如果没有歌在放，清空系统信息
        guard let song = song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        // 1. 构建基础信息字典
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0 // 1.0 表示正在播放，0.0 表示暂停
        ]
        
        // 2. 先更新基础文字信息 (此时不含图片，为了响应速度)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // 3. 异步加载封面并追加更新
        // 注意：这里不会阻塞主线程
        Task {
            if let data = await ArtworkLoader.loadArtwork(for: song) {
                // 使用跨平台方法创建 MPMediaItemArtwork
                if let artwork = createArtwork(from: data) {
                    
                    // 重新获取最新的 info (防止在异步期间 info 被其他操作覆盖)
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    
                    // 再次提交更新
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }
        }
    }
    
    // MARK: - Helper
    
    /// 跨平台创建 MPMediaItemArtwork 对象
    ///
    /// 使用 UIImage 创建 artwork。
    private func createArtwork(from data: Data) -> MPMediaItemArtwork? {
        // iOS / watchOS 实现
        guard let image = UIImage(data: data) else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
    }
}
