//
//  AudioPlayerService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import Combine
import MediaPlayer
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 音频播放服务 (AudioPlayerService)
///
/// **职责**: 作为 App 的核心播放控制器，协调音频引擎、播放列表、歌词管理和系统媒体中心。
/// **层级**: Core Layer (最高级服务)。
/// **单例**: `shared` 实例供全 App 共享状态。
///
/// 它是一个 `ObservableObject`，所有 UI 视图（Mac/iOS/Watch）都通过监听它的 `@Published` 属性来更新界面。
class AudioPlayerService: NSObject, ObservableObject {
    
    /// 全局单例
    static let shared = AudioPlayerService()
    
    // MARK: - Handoff States
    private var handoffActivity: NSUserActivity?
    private var lastHandoffUpdateTime: TimeInterval = 0
    
    // MARK: - Private Dependencies (Subsystems)
    
    /// 音频引擎：负责底层的 AVAudioPlayer 控制
    private let engine = AudioEngine()
    private let lyricsManager = LyricsManager()
    private var systemHandler: SystemMediaHandler!
    
    public let queueManager = PlaylistManager()
    
    // 用于桥接 Combine 事件
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published States (UI Data Source)
    
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentLyric: String = ""
    @Published var lyrics: [LyricLine] = []
    
    var isShuffleMode: Bool {
        get { queueManager.isShuffleMode }
        set { queueManager.isShuffleMode = newValue }
    }
    
    var isLoopMode: Bool {
        get { queueManager.isLoopMode }
        set { queueManager.isLoopMode = newValue }
    }
    
    var queue: [Song] {
        get { queueManager.isShuffleMode ? queueManager.shuffledPlaylist : queueManager.originalPlaylist }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        queueManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        setupAudioSession()
        self.systemHandler = SystemMediaHandler(service: self)
        setupEngineCallbacks()
        
        #if os(iOS)
        self.setupInterruptionHandling()
        #endif
    }
    
    private func setupAudioSession() {
        #if os(iOS) || os(watchOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [AudioPlayerService] 音频会话配置失败: \(error.localizedDescription)")
        }
        #endif
    }
    
    private func setupEngineCallbacks() {
        engine.onTimeUpdate = { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time
            if abs(time - self.lastHandoffUpdateTime) > 5.0 {
                self.updateHandoffState()
                self.lastHandoffUpdateTime = time
            }
            if let lineText = self.lyricsManager.findCurrentLine(in: self.lyrics, at: time),
               lineText != self.currentLyric {
                DispatchQueue.main.async {
                    self.currentLyric = lineText
                }
            }
        }
        
        engine.onPlaybackFinished = { [weak self] in
            DispatchQueue.main.async {
                if self?.isLoopMode == true {
                    self?.seek(to: 0)
                    self?.play(song: self!.currentSong!, playlist: self!.queueManager.originalPlaylist)
                } else {
                    self?.next()
                }
            }
        }
        
        engine.onDurationUpdate = { [weak self] dur in
            DispatchQueue.main.async { self?.duration = dur }
        }
    }
    
    private func updateSystemInfo() {
        systemHandler.updateNowPlayingInfo(
            song: currentSong,
            isPlaying: isPlaying,
            currentTime: engine.currentTime,
            duration: duration
        )
    }
    
    // MARK: - Public Control API
    
    func play(song: Song, playlist list: [Song] = []) {
        if !list.isEmpty && (list != queueManager.originalPlaylist || queueManager.originalPlaylist.isEmpty) {
            queueManager.updateList(list)
            if isShuffleMode {
                queueManager.reshuffle(keepCurrentAtTop: song)
            }
        }
        
        if isShuffleMode && queueManager.shuffledPlaylist.isEmpty && !queueManager.originalPlaylist.isEmpty {
            queueManager.reshuffle(keepCurrentAtTop: song)
        }
        
        self.currentSong = song
        engine.play(url: song.url)
        isPlaying = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLyricsForCurrentSong()
        }
        updateSystemInfo()
        
        self.updateHandoffState()
    }
    
    func pause() {
        engine.pause()
        isPlaying = false
        updateSystemInfo()
    }
    
    func resume() {
        engine.resume()
        isPlaying = true
        updateSystemInfo()
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
        updateSystemInfo()
        self.invalidateHandoff()
    }
    
    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        currentTime = time
        updateLyrics()
        updateSystemInfo()
        self.updateHandoffState()
    }
    
    func toggleShuffle() {
        isShuffleMode.toggle()
        if isShuffleMode {
            queueManager.reshuffle(keepCurrentAtTop: currentSong)
        }
    }
    
    func toggleLoop() {
        isLoopMode.toggle()
    }
    
    // MARK: - Queue Management
        
    func removeSongs(at offsets: IndexSet) {
        if isShuffleMode {
            var list = queueManager.shuffledPlaylist
            list.remove(atOffsets: offsets)
            queueManager.updateShuffledList(list)
        } else {
            var list = queueManager.originalPlaylist
            list.remove(atOffsets: offsets)
            queueManager.updateOriginalList(list)
        }
    }
    
    func moveSongs(from source: IndexSet, to destination: Int) {
        if isShuffleMode {
            var list = queueManager.shuffledPlaylist
            list.move(fromOffsets: source, toOffset: destination)
            queueManager.updateShuffledList(list)
        } else {
            var list = queueManager.originalPlaylist
            list.move(fromOffsets: source, toOffset: destination)
            queueManager.updateOriginalList(list)
        }
    }
    
    func appendToQueue(songs: [Song]) {
        var list = queue
        list.append(contentsOf: songs)
        if isShuffleMode {
            queueManager.updateShuffledList(list)
        } else {
            queueManager.updateOriginalList(list)
        }
    }
    
    func addToNext(song: Song) {
        var activeQueue = queue
        guard let current = currentSong,
              let currentIndex = activeQueue.firstIndex(where: { $0.id == current.id }) else {
            play(song: song, playlist: [song])
            return
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex <= activeQueue.count {
            activeQueue.insert(song, at: nextIndex)
        } else {
            activeQueue.append(song)
        }
        
        if isShuffleMode {
            queueManager.updateShuffledList(activeQueue)
        } else {
            queueManager.updateOriginalList(activeQueue)
        }
    }
    
    // MARK: - Navigation Logic
    
    func next() {
        if let nextSong = queueManager.getNextSong(after: currentSong) {
            play(song: nextSong)
        } else {
            stop()
        }
    }
    
    func previous() {
        if engine.currentTime > 3.0 {
            seek(to: 0)
            return
        }
        if let prevSong = queueManager.getPreviousSong(before: currentSong) {
            play(song: prevSong)
        }
    }
    
    // MARK: - Lyrics Logic
    
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
    
    // MARK: - Handoff Logic
        
    private func updateHandoffState() {
        #if os(iOS)
        // 仅允许 iOS 端执行系统级状态广播
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let song = self.currentSong else {
                self.handoffActivity?.invalidate()
                self.handoffActivity = nil
                return
            }
            
            if self.handoffActivity == nil {
                self.handoffActivity = NSUserActivity(activityType: "com.soloist.handoff.playback")
                self.handoffActivity?.isEligibleForHandoff = true
                self.handoffActivity?.title = "正在播放: \(song.title)"
            }
            
            self.handoffActivity?.addUserInfoEntries(from: [
                "songID": song.id,
                "currentTime": self.currentTime
            ])
            
            self.handoffActivity?.becomeCurrent()
        }
        #else
        // macOS 端由于采用 UIElement(Agent) 形态，底层禁止接力广播
        // 物理切断发射逻辑，节省后台系统资源开销
        return
        #endif
    }

    /// 彻底切断 Handoff 广播 (用于停止播放时)
    private func invalidateHandoff() {
        handoffActivity?.invalidate()
        handoffActivity = nil
    }

}
