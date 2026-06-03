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
import UIKit

/// 音频播放服务 (AudioPlayerService)
///
/// **职责**: 作为 App 的核心播放控制器，协调音频引擎、播放列表、歌词管理和系统媒体中心。
/// **层级**: Core Layer (最高级服务)。
/// **单例**: `shared` 作为 App 内唯一的播放协调器，供界面、系统媒体中心和快捷指令共用。
///
/// 它是一个 `ObservableObject`，所有 UI 视图（Mac/iOS/Watch）都通过监听它的 `@Published` 属性来更新界面。
class AudioPlayerService: NSObject, ObservableObject, NSUserActivityDelegate {
    
    /// 全局单例
    static let shared = AudioPlayerService()
    
    // MARK: - Private Dependencies (Subsystems)
    
    /// 音频引擎：负责底层的 AVAudioPlayer 控制
    private let engine = AudioEngine()
    private let lyricsManager = LyricsManager()
    private var systemHandler: SystemMediaHandler!
    
    public let queueManager = PlaylistManager()
    
    // 用于桥接 Combine 事件
    private var cancellables = Set<AnyCancellable>()
    private var shouldLoadLyricsWhenDurationReady = false
    
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
            DispatchQueue.main.async {
                self.currentTime = time
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
                guard let self = self else { return }
                self.next()
            }
        }
        
        engine.onDurationUpdate = { [weak self] dur in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.duration = dur
                if self.shouldLoadLyricsWhenDurationReady {
                    self.shouldLoadLyricsWhenDurationReady = false
                    self.loadLyricsForCurrentSong()
                }
            }
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
        self.shouldLoadLyricsWhenDurationReady = true
        engine.play(url: song.url)
        loadLyricsForCurrentSong()
        isPlaying = true
        
        updateSystemInfo()
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
    }
    
    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        currentTime = time
        updateLyrics()
        updateSystemInfo()
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
        if duration <= 0, song.lrcURL == nil, (song.embeddedLyrics?.isEmpty ?? true) {
            return
        }
        self.lyrics = []
        self.currentLyric = song.title
        
        lyricsManager.fetchLyrics(for: song, duration: duration) { [weak self] parsed, updatedSong, _ in
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
