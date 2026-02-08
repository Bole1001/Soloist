//
//  AudioPlayerService+Interruption.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import Foundation
import AVFoundation

extension AudioPlayerService {
    
    // MARK: - Public Setup
    
    /// 配置音频中断监听 (仅 iOS/WatchOS 有效)
    /// 包含：电话打断、闹钟、拔插耳机等
    func setupInterruptionHandling() {
        let center = NotificationCenter.default
        
        // 1. 监听音频打断 (Interruption) - 例如电话接入
        center.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        // 2. 监听路由改变 (Route Change) - 例如拔出耳机
        center.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 中断开始（例如电话接通）：必须暂停，且通常不需要更新UI为暂停（系统会接管），但为了安全我们同步状态
            print("📞 [AudioService] 音频中断开始：暂停播放")
            // 注意：必须切回主线程操作 UI 绑定的属性
            DispatchQueue.main.async {
                self.pause()
            }
            
        case .ended:
            // 中断结束：检查是否应该恢复播放
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) {
                print("📞 [AudioService] 音频中断结束：恢复播放")
                DispatchQueue.main.async {
                    self.resume()
                }
            } else {
                print("📞 [AudioService] 音频中断结束：保持暂停")
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // 我们主要关心：旧设备不可用 (OldDeviceUnavailable) -> 即“拔出耳机”
        switch reason {
        case .oldDeviceUnavailable:
            print("🎧 [AudioService] 耳机拔出：暂停播放")
            DispatchQueue.main.async {
                self.pause()
            }
            
        case .newDeviceAvailable:
            print("🎧 [AudioService] 耳机插入：通常不自动播放，保持现状")
            
        default:
            break
        }
    }
}
