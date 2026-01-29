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
    
    // MARK: - 状态发布
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentLyric: String = ""
    @Published var lyrics: [LyricLine] = [] // 全部歌词
    
    // 播放队列
    private var playlist: [Song] = []
    
    // 定时器
    private var timer: Timer?
    
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
    }
    
    // MARK: - 公开控制方法
    
    func play(song: Song, playlist: [Song]) {
        self.playlist = playlist
        self.currentSong = song
        startPlayback(url: song.url)
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if player.isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        startTimer()
    }
    
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
    
    func next() {
        guard let current = currentSong, let index = playlist.firstIndex(of: current) else { return }
        let nextIndex = index + 1
        
        if nextIndex < playlist.count {
            let nextSong = playlist[nextIndex]
            currentSong = nextSong
            startPlayback(url: nextSong.url)
        } else {
            stop()
        }
    }
    
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
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            
            isPlaying = true
            duration = player?.duration ?? 0
            
            // ✨ 核心修改：歌词加载策略
            // 策略 A: 优先找外挂 .lrc 文件
            if let lrcUrl = currentSong?.lrcURL {
                print("加载外挂歌词: \(lrcUrl.lastPathComponent)")
                self.lyrics = LRCParser.parse(url: lrcUrl)
                
            // 策略 B: 如果没有，找内嵌歌词 (embeddedLyrics)
            } else if let embedded = currentSong?.embeddedLyrics, !embedded.isEmpty {
                print("加载内嵌歌词...")
                self.lyrics = LRCParser.parse(content: embedded)
                
            } else {
                // 策略 C: 都没有
                print("无歌词")
                self.lyrics = []
                self.currentLyric = ""
            }
            
            startTimer()
            
        } catch {
            print("播放出错: \(error)")
            stop()
        }
    }
    
    // MARK: - 定时器与歌词同步
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            
            self.currentTime = player.currentTime
            self.updateLyrics()
        }
    }
    
    private func updateLyrics() {
        guard !lyrics.isEmpty else { return }
        
        if let line = lyrics.last(where: { $0.startTime <= currentTime }) {
            if currentLyric != line.text {
                currentLyric = line.text
            }
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            next()
        }
    }
}
