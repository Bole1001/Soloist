//
//  AudioEngine.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import Foundation
import AVFoundation

/// 音频引擎 (AudioEngine)
///
/// **职责**: 负责最底层的音频播放控制。
/// **层级**: Core Layer (被 AudioPlayerService 持有)。
///
/// 它封装了 `AVAudioPlayer`，提供了更友好的 Swift 接口，并负责管理播放进度定时器。
/// 所有的播放状态变化（开始、暂停、进度、结束）都通过闭包（Closure）向外汇报。
class AudioEngine: NSObject, AVAudioPlayerDelegate {
    
    // MARK: - Private Properties
    
    /// 底层播放器实例
    private var player: AVAudioPlayer?
    
    /// 进度定时器
    ///
    /// 用于每隔 0.1 秒刷新一次播放进度，驱动 UI 上的进度条更新。
    private var timer: Timer?
    
    // MARK: - Public Callbacks (Delegates)
    
    // 这些闭包是 AudioEngine 向 Service 汇报情况的“对讲机”。
    
    /// 进度更新回调
    /// - Parameter: 当前播放时间 (TimeInterval)
    var onTimeUpdate: ((TimeInterval) -> Void)?
    
    /// 播放结束回调
    /// 当一首歌自然播放结束时触发（用户手动切歌不触发此回调）。
    var onPlaybackFinished: (() -> Void)?
    
    /// 时长获取回调
    /// 当成功加载歌曲并获取到总时长时触发。
    var onDurationUpdate: ((TimeInterval) -> Void)?

    // MARK: - Control Methods
    
    /// 播放指定 URL 的音频文件
    ///
    /// - Parameter url: 本地音频文件的 URL。
    func play(url: URL) {
        // 1. 播放新歌前，必须彻底停止上一首，释放资源
        stop()
        
        do {
            // 2. 初始化播放器
            // 这里可能会因为文件损坏或格式不支持抛出异常
            player = try AVAudioPlayer(contentsOf: url)
            
            // 3. 设置代理，为了监听“播放自然结束”事件
            player?.delegate = self
            
            // 4. 准备播放 (缓冲数据，降低播放延迟)
            player?.prepareToPlay()
            
            // 5. 开始播放
            player?.play()
            
            // 6. 立即汇报总时长 (让 UI 知道进度条总长度)
            onDurationUpdate?(player?.duration ?? 0)
            
            // 7. 启动进度监控
            startTimer()
            
        } catch {
            print("❌ [AudioEngine] 播放出错: \(error.localizedDescription)")
        }
    }

    /// 暂停播放
    ///
    /// 暂停后，音频停在当前位置，定时器停止以节省 CPU。
    func pause() {
        player?.pause()
        stopTimer()
    }

    /// 恢复播放
    ///
    /// 从暂停位置继续播放，并重新启动定时器。
    func resume() {
        player?.play()
        startTimer()
    }

    /// 停止播放
    ///
    /// 彻底停止播放，重置播放头，并销毁播放器实例释放内存。
    func stop() {
        player?.stop()
        player = nil // 释放 AVAudioPlayer 对象
        stopTimer()  // 销毁定时器
    }

    /// 跳转到指定时间 (Seek)
    ///
    /// - Parameter time: 目标时间点（秒）。
    func seek(to time: TimeInterval) {
        // AVAudioPlayer 允许直接修改 currentTime 实现跳转
        player?.currentTime = time
    }

    // MARK: - State Properties
    
    /// 当前播放时间 (只读)
    /// 如果播放器未初始化，返回 0。
    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    /// 是否正在播放 (只读)
    var isPlaying: Bool {
        player?.isPlaying ?? false
    }
    
    /// 音频总时长 (只读)
    var duration: TimeInterval {
        player?.duration ?? 0
    }

    // MARK: - Timer Logic
    
    /// 启动内部定时器
    ///
    /// 以 0.1秒 (10Hz) 的频率向外发送当前进度。
    /// 这个频率足以让 UI 进度条看起来是平滑移动的。
    private func startTimer() {
        // 先停掉旧的，防止多重定时器导致回调混乱
        stopTimer()
        
        // 注意：这里使用 [weak self] 是为了防止循环引用 (Retain Cycle)
        // 否则 Timer 强引用 self，self 强引用 Timer，导致 AudioEngine 永远无法释放。
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 只有当播放器真的在动时，才回调，避免暂停时还在疯狂发通知
            if self.player?.isPlaying == true {
                self.onTimeUpdate?(self.player?.currentTime ?? 0)
            }
        }
    }

    /// 销毁定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioPlayerDelegate
    
    /// 代理方法：当音频播放自然完成时调用
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // 只有解码成功且播放完毕才通知
            // 上层 Service 收到这个通知后，通常会执行“自动下一首”逻辑
            onPlaybackFinished?()
        }
    }
}
