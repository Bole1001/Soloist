//
//  AudioPlayerService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

// ✨ 修复：根据平台引入正确的 UI 库
#if os(macOS)
import AppKit
#else
import UIKit
#endif

class AudioPlayerService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    private var player: AVAudioPlayer?
    
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
            if isShuffleMode {
                shufflePlaylist(keepCurrentAtTop: true)
            }
        }
    }
    
    // 循环模式开关
    @Published var isLoopMode: Bool = true
    
    // 播放队列
    private var originalPlaylist: [Song] = []
    private var shuffledPlaylist: [Song] = []
    
    // 定时器
    private var timer: Timer?
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupAudioSession()
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
    
    // MARK: - 系统媒体控制 (键盘/Touch Bar/控制中心)
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
                self?.player?.currentTime = event.positionTime
                self?.currentTime = event.positionTime
                self?.updateNowPlayingInfo()
                return .success
            }
            return .commandFailed
        }
    }
    
    // MARK: - 更新系统播放信息
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        
        if let song = currentSong {
            info[MPMediaItemPropertyTitle] = song.title
            info[MPMediaItemPropertyArtist] = song.artist
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            // ✨ 修复：根据平台处理图片
            if let data = song.artworkData {
                #if os(macOS)
                if let nsImage = NSImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in return nsImage }
                    info[MPMediaItemPropertyArtwork] = artwork
                }
                #else
                if let uiImage = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in return uiImage }
                    info[MPMediaItemPropertyArtwork] = artwork
                }
                #endif
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - 公开控制方法
    
    func play(song: Song, playlist: [Song]) {
        self.originalPlaylist = playlist
        self.currentSong = song
        
        if isShuffleMode {
            shufflePlaylist(keepCurrentAtTop: true)
        }
        
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
    
    func toggleShuffle() {
        isShuffleMode.toggle()
    }
    
    func toggleLoop() {
        isLoopMode.toggle()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        updateNowPlayingInfo()
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlayingInfo()
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - 切歌逻辑
    
    func next() {
        guard let current = currentSong else { return }
        
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard let index = activeList.firstIndex(where: { $0.id == current.id }) else { return }
        
        var nextIndex = index + 1
        
        if nextIndex >= activeList.count {
            if isLoopMode {
                if isShuffleMode {
                    reshuffleForNextRound()
                    nextIndex = 0
                } else {
                    nextIndex = 0
                }
            } else {
                stop()
                return
            }
        }
        
        let finalList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        let nextSong = finalList[nextIndex]
        currentSong = nextSong
        startPlayback(url: nextSong.url)
    }
    
    func previous() {
        guard let current = currentSong else { return }
        
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard let index = activeList.firstIndex(where: { $0.id == current.id }) else { return }
        
        var prevIndex = index - 1
        
        if prevIndex < 0 {
            if isLoopMode {
                prevIndex = activeList.count - 1
            } else {
                return
            }
        }
        
        let prevSong = activeList[prevIndex]
        currentSong = prevSong
        startPlayback(url: prevSong.url)
    }
    
    // MARK: - 内部逻辑
    
    private func shufflePlaylist(keepCurrentAtTop: Bool) {
        var shuffled = originalPlaylist.shuffled()
        if keepCurrentAtTop, let current = currentSong, let index = shuffled.firstIndex(where: { $0.id == current.id }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        self.shuffledPlaylist = shuffled
        print("随机列表生成")
    }
    
    private func reshuffleForNextRound() {
        self.shuffledPlaylist = originalPlaylist.shuffled()
        print("新一轮循环，已重新彻底洗牌")
    }
    
    private func startPlayback(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            
            isPlaying = true
            duration = player?.duration ?? 0
            
            if let lrcUrl = currentSong?.lrcURL {
                self.lyrics = LRCParser.parse(url: lrcUrl)
            } else if let embedded = currentSong?.embeddedLyrics, !embedded.isEmpty {
                self.lyrics = LRCParser.parse(content: embedded)
            } else {
                self.lyrics = []
                self.currentLyric = ""
            }
            
            startTimer()
            updateNowPlayingInfo()
            
        } catch {
            print("播放出错: \(error)")
            stop()
        }
    }
    
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
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            next()
        }
    }
}
