//
//  AudioEngine.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import Foundation
import AVFoundation

class AudioEngine: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    // MARK: - 回调闭包 (向 Service 汇报情况)
    // 进度更新 (当前时间)
    var onTimeUpdate: ((TimeInterval) -> Void)?
    // 播放结束
    var onPlaybackFinished: (() -> Void)?
    // 获取到时长
    var onDurationUpdate: ((TimeInterval) -> Void)?

    // MARK: - 控制方法
    func play(url: URL) {
        // 先停止之前的播放
        stop()
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            
            // 汇报总时长
            onDurationUpdate?(player?.duration ?? 0)
            
            // 启动进度定时器
            startTimer()
        } catch {
            print("❌ [AudioEngine] 播放出错: \(error)")
        }
    }

    func pause() {
        player?.pause()
        stopTimer()
    }

    func resume() {
        player?.play()
        startTimer()
    }

    func stop() {
        player?.stop()
        player = nil
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
    }

    // MARK: - 状态获取
    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }
    
    var duration: TimeInterval {
        player?.duration ?? 0
    }

    // MARK: - 内部定时器
    private func startTimer() {
        stopTimer()
        // 0.1秒汇报一次进度
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.onTimeUpdate?(self.player?.currentTime ?? 0)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            onPlaybackFinished?()
        }
    }
}
