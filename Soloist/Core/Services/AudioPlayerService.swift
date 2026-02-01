//
//  AudioPlayerService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import Combine
import MediaPlayer

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()
    
    // MARK: - 核心助手模块
    private let engine = AudioEngine()
    private let playlist = PlaylistManager()
    private let lyricsManager = LyricsManager()
    
    // ✨ 新增：系统媒体管家
    private var systemHandler: SystemMediaHandler!
    
    // MARK: - 状态发布
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentLyric: String = ""
    @Published var lyrics: [LyricLine] = []
    
    @Published var isShuffleMode: Bool = true {
        didSet {
            playlist.isShuffleMode = isShuffleMode
            if isShuffleMode {
                playlist.reshuffle(keepCurrentAtTop: currentSong)
            }
        }
    }
    
    @Published var isLoopMode: Bool = true {
        didSet { playlist.isLoopMode = isLoopMode }
    }
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupAudioSession()
        
        // ✨ 初始化管家，把自己(self)传过去供其调用
        self.systemHandler = SystemMediaHandler(service: self)
        
        setupEngineCallbacks()
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
    
    // MARK: - 引擎回调
    private func setupEngineCallbacks() {
        engine.onTimeUpdate = { [weak self] time in
            DispatchQueue.main.async {
                self?.currentTime = time
                self?.updateLyrics()
            }
        }
        
        engine.onPlaybackFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.next()
            }
        }
        
        engine.onDurationUpdate = { [weak self] dur in
            DispatchQueue.main.async {
                self?.duration = dur
            }
        }
    }
    
    // MARK: - 私有辅助方法：统一调用 Handler
    private func updateSystemInfo() {
        systemHandler.updateNowPlayingInfo(
            song: currentSong,
            isPlaying: isPlaying,
            currentTime: engine.currentTime,
            duration: duration
        )
    }
    
    // MARK: - 播放控制 API
    
    func play(song: Song, playlist list: [Song]) {
        self.playlist.updateList(list)
        if isShuffleMode && playlist.shuffledPlaylist.isEmpty {
            playlist.reshuffle(keepCurrentAtTop: song)
        }
        
        self.currentSong = song
        engine.play(url: song.url)
        isPlaying = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLyricsForCurrentSong()
        }
        
        // ✨ 更新系统信息
        updateSystemInfo()
    }
    
    func pause() {
        engine.pause()
        isPlaying = false
        updateSystemInfo() // ✨
    }
    
    func resume() {
        engine.resume()
        isPlaying = true
        updateSystemInfo() // ✨
    }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }
    
    func stop() {
        engine.stop()
        currentSong = nil
        isPlaying = false
        currentLyric = ""
        currentTime = 0
        lyrics = []
        
        // ✨ 清空系统信息
        updateSystemInfo()
    }
    
    // ✨ 新增：公开给 SystemMediaHandler 使用
    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        
        // 手动立即更新 UI 时间，防止跳动
        currentTime = time
        updateLyrics()
        
        updateSystemInfo()
    }
    
    func toggleShuffle() {
        isShuffleMode.toggle()
    }
    
    func toggleLoop() {
        isLoopMode.toggle()
    }
    
    // MARK: - 切歌逻辑
    func next() {
        if let nextSong = playlist.getNextSong(after: currentSong) {
            play(song: nextSong, playlist: playlist.originalPlaylist)
        } else {
            stop()
        }
    }
    
    func previous() {
        if engine.currentTime > 3.0 {
            seek(to: 0) // 复用 seek 方法
            return
        }
        
        if let prevSong = playlist.getPreviousSong(before: currentSong) {
            play(song: prevSong, playlist: playlist.originalPlaylist)
        }
    }
    
    // MARK: - 歌词逻辑
    private func updateLyrics() {
        if let lineText = lyricsManager.findCurrentLine(in: lyrics, at: currentTime) {
            if currentLyric != lineText {
                currentLyric = lineText
            }
        }
    }

    private func loadLyricsForCurrentSong() {
        guard let song = currentSong else { return }
        self.lyrics = []
        self.currentLyric = song.title
        
        lyricsManager.fetchLyrics(for: song, duration: duration) { [weak self] parsed, updatedSong in
            DispatchQueue.main.async {
                guard let self = self, self.currentSong?.id == song.id else { return }
                self.lyrics = parsed
                if let newSong = updatedSong {
                    self.currentSong = newSong
                }
            }
        }
    }
}
