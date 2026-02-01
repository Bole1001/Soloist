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
    
    private let engine = AudioEngine()
    
    // MARK: - 状态发布
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentLyric: String = ""
    @Published var lyrics: [LyricLine] = []
    
    // 随机模式开关
    @Published var isShuffleMode: Bool = true {
        didSet {
            playlist.isShuffleMode = isShuffleMode
            if isShuffleMode {
                playlist.reshuffle(keepCurrentAtTop: currentSong)
            }
        }
    }
    
    // 循环模式开关
    @Published var isLoopMode: Bool = true {
        didSet {
            playlist.isLoopMode = isLoopMode
        }
    }
    
    // 播放队列
    private let playlist = PlaylistManager()
    private let lyricsManager = LyricsManager()
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupAudioSession()
        setupEngineCallbacks()
        setupRemoteCommandCenter()
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
    
    private func setupEngineCallbacks() {
        // 进度更新
        engine.onTimeUpdate = { [weak self] time in
            DispatchQueue.main.async {
                self?.currentTime = time
                self?.updateLyrics() // 驱动歌词更新
            }
        }
        
        // 播放结束 -> 自动下一首
        engine.onPlaybackFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.next()
            }
        }
        
        // 时长更新
        engine.onDurationUpdate = { [weak self] dur in
            DispatchQueue.main.async {
                self?.duration = dur
            }
        }
    }
    
    // MARK: - 系统媒体控制
    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                
                self?.engine.seek(to: event.positionTime)
                
                // 这里手动更一下状态，UI 响应更快
                self?.currentTime = event.positionTime
                self?.updateNowPlayingInfo()
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - 更新系统播放信息
    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: engine.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        
        // 后台异步加载封面 (保持不变)
        Task {
            if let data = await ArtworkLoader.loadArtwork(for: song) {
                #if os(macOS)
                if let nsImage = NSImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in return nsImage }
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
                #else
                if let uiImage = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in return uiImage }
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
                #endif
            }
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
    
    // MARK: - 公开控制方法
    func play(song: Song, playlist list: [Song]) {
        self.playlist.updateList(list)
        if isShuffleMode && playlist.shuffledPlaylist.isEmpty {
            playlist.reshuffle(keepCurrentAtTop: song)
        }
        
        self.currentSong = song
        
        engine.play(url: song.url)
        
        // 更新 Service 状态
        isPlaying = true
        
        // 延迟加载歌词
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLyricsForCurrentSong()
        }
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if engine.isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func toggleShuffle() {
        isShuffleMode.toggle()
    }
    
    func toggleLoop() {
        isLoopMode.toggle()
    }
    
    func pause() {
        engine.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func resume() {
        engine.resume()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func stop() {
        engine.stop()
        
        currentSong = nil
        isPlaying = false
        currentLyric = ""
        currentTime = 0
        lyrics = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
            engine.seek(to: 0)
            updateNowPlayingInfo()
            return
        }
        
        if let prevSong = playlist.getPreviousSong(before: currentSong) {
            play(song: prevSong, playlist: playlist.originalPlaylist)
        }
    }
}
