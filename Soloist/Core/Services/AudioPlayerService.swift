//
//  AudioPlayerService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import AVFoundation
import Combine

class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    private var player: AVAudioPlayer?
    
    // MARK: - 状态发布 (UI 监听这些变量)
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0  // 当前播放进度(秒)
    @Published var duration: TimeInterval = 0     // 总时长
    @Published var currentLyric: String = ""      // 当前这句歌词
    
    // 播放队列
    private var playlist: [Song] = []
    
    // 歌词相关
    @Published var lyrics: [LyricLine] = []          // 当前这首歌的所有歌词
    private var timer: Timer?                     // 进度定时器
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        #if os(iOS) || os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
        #endif
        // macOS 不需要手动配置 AudioSession
    }
    
    // MARK: - 公开控制方法
    
    /// 播放指定歌曲，并更新播放列表
    func play(song: Song, playlist: [Song]) {
        self.playlist = playlist
        self.currentSong = song
        startPlayback(url: song.url)
    }
    
    /// 暂停/继续切换
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    /// 暂停 (内部使用)
    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate() // 暂停时停止计时器，节省性能
    }
    
    /// 恢复播放 (内部使用)
    func resume() {
        player?.play()
        isPlaying = true
        startTimer() // 恢复播放时必须重启计时器
    }
    
    /// 停止播放
    func stop() {
        player?.stop()
        player = nil
        currentSong = nil
        isPlaying = false
        timer?.invalidate()
        currentLyric = ""
        currentTime = 0
        lyrics = []
    }
    
    /// 下一首
    func next() {
        guard let current = currentSong, let index = playlist.firstIndex(of: current) else { return }
        let nextIndex = index + 1
        
        if nextIndex < playlist.count {
            let nextSong = playlist[nextIndex]
            currentSong = nextSong
            startPlayback(url: nextSong.url)
        } else {
            // 列表播完了，停止播放
            stop()
        }
    }
    
    /// 上一首
    func previous() {
        guard let current = currentSong, let index = playlist.firstIndex(of: current) else { return }
        let prevIndex = index - 1
        
        if prevIndex >= 0 {
            let prevSong = playlist[prevIndex]
            currentSong = prevSong
            startPlayback(url: prevSong.url)
        }
    }
    
    // MARK: - 播放核心逻辑
    
    private func startPlayback(url: URL) {
        do {
            // 1. 初始化播放器
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self // 设置代理，用于监听播放结束
            player?.prepareToPlay()
            player?.play()
            
            // 2. 更新基础状态
            isPlaying = true
            duration = player?.duration ?? 0
            
            // 3. 加载歌词
            if let lrcUrl = currentSong?.lrcURL {
                self.lyrics = LRCParser.parse(url: lrcUrl)
                print("歌词加载成功，共 \(self.lyrics.count) 行")
            } else {
                self.lyrics = []
                self.currentLyric = "无歌词"
            }
            
            // 4. 启动定时器 (同步进度和歌词)
            startTimer()
            
        } catch {
            print("播放出错: \(error)")
            stop()
        }
    }
    
    // MARK: - 定时器与歌词同步
    
    private func startTimer() {
        // 先销毁旧的，防止重复
        timer?.invalidate()
        
        // 每 0.1 秒执行一次
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            
            // 1. 更新播放进度条
            self.currentTime = player.currentTime
            
            // 2. 更新歌词
            self.updateLyrics()
        }
    }
    
    private func updateLyrics() {
        guard !lyrics.isEmpty else { return }
        
        // 算法：找到 startTime 小于等于当前时间的最后一行
        if let line = lyrics.last(where: { $0.startTime <= currentTime }) {
            // 只有当歌词内容变了才更新，避免 UI 无意义重绘
            if currentLyric != line.text {
                currentLyric = line.text
            }
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    // 监听播放结束，自动切下一首
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("当前歌曲播放完毕，自动下一首")
            next()
        }
    }
}
