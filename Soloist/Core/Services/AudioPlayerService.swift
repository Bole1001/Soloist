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
    
    // MARK: - Private Dependencies (Subsystems)
    
    /// 音频引擎：负责底层的 AVAudioPlayer 控制
    private let engine = AudioEngine()
    
    /// 播放列表管理器：负责随机/循环/切歌逻辑
    private let playlist = PlaylistManager()
    
    /// 歌词管理器：负责加载、解析和查找当前歌词
    private let lyricsManager = LyricsManager()
    
    /// 系统媒体管家：负责与控制中心 (Control Center) 和锁屏界面交互
    /// 注意：这是一个 Optional，但在 init 中会立即初始化
    private var systemHandler: SystemMediaHandler!
    
    // MARK: - Published States (UI Data Source)
    
    /// 当前播放的歌曲
    @Published var currentSong: Song?
    
    /// 播放状态 (true = 正在播放, false = 暂停或停止)
    @Published var isPlaying: Bool = false
    
    /// 当前播放进度 (秒)
    //@Published var currentTime: TimeInterval = 0
    var currentTime: TimeInterval = 0
    
    /// 当前歌曲总时长 (秒)
    @Published var duration: TimeInterval = 0
    
    /// 当前正在唱的那一行歌词文本
    @Published var currentLyric: String = ""
    
    /// 当前歌曲的完整歌词列表
    @Published var lyrics: [LyricLine] = []
    
    /// 当前播放队列
    @Published var queue: [Song] = []
    
    /// 随机播放模式开关
    @Published var isShuffleMode: Bool = true {
        didSet {
            playlist.isShuffleMode = isShuffleMode
            
            // 切换模式时，立即刷新 UI 队列
            if isShuffleMode {
                // 切换到随机：如果随机表空，先洗牌
                if playlist.shuffledPlaylist.isEmpty {
                     playlist.reshuffle(keepCurrentAtTop: currentSong)
                }
                self.queue = playlist.shuffledPlaylist
            } else {
                // 切换到顺序
                self.queue = playlist.originalPlaylist
            }
        }
    }
    
    /// 循环模式开关 (单曲循环/列表循环)
    @Published var isLoopMode: Bool = false {
        didSet { playlist.isLoopMode = !isLoopMode }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // 1. 配置音频会话 (iOS/WatchOS 必须步骤)
        setupAudioSession()
        
        // 2. 初始化系统媒体管家
        // 关键点：将 self 传递给 handler，建立双向引用，以便 handler 能反向调用 service 的 seek/play/pause 方法
        self.systemHandler = SystemMediaHandler(service: self)
        
        // 3. 绑定底层引擎的回调
        setupEngineCallbacks()
        
        #if os(iOS)
        self.setupInterruptionHandling()
        #endif
    }
    
    /// 配置 AVAudioSession
    /// 确保 App 在静音模式下也能发声，并支持后台播放。
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
    
    // MARK: - Engine Callbacks Wiring
    
    /// 连接 AudioEngine 的闭包回调到 Service 的状态更新逻辑
    private func setupEngineCallbacks() {
        // 1.只有歌词变化时才通知 UI
        engine.onTimeUpdate = { [weak self] time in
                    guard let self = self else { return }
                    
                    // 1. 静默更新数值 (原子操作，线程安全基本没问题，或者加锁)
                    self.currentTime = time
                    
                    // 2. 检查歌词 (只有行数变了才去主线程刷新 UI)
                    if let lineText = self.lyricsManager.findCurrentLine(in: self.lyrics, at: time),
                       lineText != self.currentLyric {
                        
                        DispatchQueue.main.async {
                            self.currentLyric = lineText
                        }
                    }
                }
        
        // 2. 自然播放结束
        engine.onPlaybackFinished = { [weak self] in
            DispatchQueue.main.async {
                // false = 单曲循环：进度归零，重新播放
                if self?.isLoopMode == true {
                    self?.seek(to: 0)
                    self?.play(song: self!.currentSong!, playlist: self!.playlist.originalPlaylist) // 重新激活播放状态
                }
                // true = 列表循环：切下一首
                else {
                    self?.next()
                }
            }
        }
        
        // 3. 歌曲时长更新
        engine.onDurationUpdate = { [weak self] dur in
            DispatchQueue.main.async {
                self?.duration = dur
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// 同步当前状态到系统控制中心 (MPNowPlayingInfoCenter)
    private func updateSystemInfo() {
        systemHandler.updateNowPlayingInfo(
            song: currentSong,
            isPlaying: isPlaying,
            currentTime: engine.currentTime,
            duration: duration
        )
    }
    
    // MARK: - Public Control API
    
    /// 播放指定歌曲
    ///
    /// - Parameters:
    ///   - song: 目标歌曲
    ///   - list: 该歌曲所属的播放列表 (用于后续切歌)
    func play(song: Song, playlist list: [Song]) {
        // 1. 列表更新逻辑
        // 如果传入的新列表和当前列表不一样，或者当前列表为空，则更新
        if list != playlist.originalPlaylist || playlist.originalPlaylist.isEmpty {
            self.playlist.updateList(list)
            
            // 如果是随机模式，必须立即洗牌，生成 shuffledPlaylist
            if isShuffleMode {
                playlist.reshuffle(keepCurrentAtTop: song)
            }
        }
        
        // 2. 双重保险：如果是随机模式，但随机表居然是空的（防止 Bug），强制洗一次
        if isShuffleMode && playlist.shuffledPlaylist.isEmpty && !list.isEmpty {
            print("⚠️ [AudioService] 检测到随机表为空，强制重新洗牌")
            playlist.reshuffle(keepCurrentAtTop: song)
        }
        
        // 3. ✨ 关键步骤：先更新 currentSong，再同步 queue
        self.currentSong = song
        
        // 根据模式决定 UI 显示哪个队列
        if isShuffleMode {
            self.queue = playlist.shuffledPlaylist
        } else {
            self.queue = playlist.originalPlaylist
        }
        
        // 4. 指挥引擎开始播放
        engine.play(url: song.url)
        isPlaying = true
        
        // 5. 异步加载歌词
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadLyricsForCurrentSong()
        }
        
        // 6. 更新系统锁屏信息
        updateSystemInfo()
    }
    
    /// 暂停播放
    func pause() {
        engine.pause()
        isPlaying = false
        updateSystemInfo()
    }
    
    /// 恢复播放
    func resume() {
        engine.resume()
        isPlaying = true
        updateSystemInfo()
    }
    
    /// 切换播放/暂停状态
    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }
    
    /// 停止播放并清空状态
    func stop() {
        engine.stop()
        currentSong = nil
        isPlaying = false
        currentLyric = ""
        currentTime = 0
        lyrics = []
        
        // 清空锁屏信息
        updateSystemInfo()
    }
    
    /// 跳转到指定时间 (Seek)
    /// - Parameter time: 目标时间 (秒)
    func seek(to time: TimeInterval) {
        engine.seek(to: time)
        
        // 立即更新 UI 状态，防止进度条“回弹”
        currentTime = time
        // 立即更新歌词，防止歌词与声音不同步
        updateLyrics()
        
        // 通知系统中心进度已改变
        updateSystemInfo()
    }
    
    func toggleShuffle() {
        isShuffleMode.toggle()
    }
    
    func toggleLoop() {
        isLoopMode.toggle()
    }
    
    // MARK: - Queue Management
        
    /// 删除队列中的歌曲
    func removeSongs(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)

        if isShuffleMode {
            playlist.updateShuffledList(queue)
        } else {
            playlist.updateOriginalList(queue)
        }
    }
    
    /// 拖拽排序
    func moveSongs(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        
        if isShuffleMode {
            playlist.updateShuffledList(queue)
        } else {
            playlist.updateOriginalList(queue)
        }
    }
    
    /// 添加歌曲到队列末尾
    func appendToQueue(songs: [Song]) {
        queue.append(contentsOf: songs)
        playlist.updateList(queue)
    }
    
    // MARK: - Queue Insert & Append (插队功能)
        
    /// 下一首播放 (插队)
    /// 逻辑：找到当前播放歌曲的位置，把新歌插入到它后面
    func addToNext(song: Song) {
        // 1. 如果当前没有播放歌曲，或者队列为空，直接当做第一首播放
        guard let current = currentSong,
              let currentIndex = queue.firstIndex(where: { $0.id == current.id }) else {
            play(song: song, playlist: [song])
            return
        }
        
        // 2. 插入到当前位置 + 1
        let nextIndex = currentIndex + 1
        
        // 防止数组越界
        if nextIndex <= queue.count {
            queue.insert(song, at: nextIndex)
        } else {
            queue.append(song)
        }
        
        // 3. 根据当前模式，同步到底层数据
        if isShuffleMode {
            playlist.updateShuffledList(queue)
        } else {
            playlist.updateOriginalList(queue)
        }
    }
    
    // MARK: - Navigation Logic
    
    /// 下一首
    func next() {
        // 让 PlaylistManager 决定下一首是谁
        if let nextSong = playlist.getNextSong(after: currentSong) {
            play(song: nextSong, playlist: playlist.originalPlaylist)
        } else {
            // 如果没有下一首了（且不是循环模式），则停止
            stop()
        }
    }
    
    /// 上一首
    func previous() {
        // 逻辑：如果当前播放了超过 3 秒，按上一首应该是“重头开始放这首歌”
        if engine.currentTime > 3.0 {
            seek(to: 0)
            return
        }
        
        // 否则切到列表里的上一首
        if let prevSong = playlist.getPreviousSong(before: currentSong) {
            play(song: prevSong, playlist: playlist.originalPlaylist)
        }
    }
    
    // MARK: - Lyrics Logic
    
    /// 根据当前时间查找并更新 currentLyric
    private func updateLyrics() {
        if let lineText = lyricsManager.findCurrentLine(in: lyrics, at: currentTime) {
            // 只有当歌词行真正改变时才更新，减少 UI 刷新频率
            if currentLyric != lineText {
                currentLyric = lineText
            }
        }
    }

    /// 为当前歌曲加载歌词
    private func loadLyricsForCurrentSong() {
        guard let song = currentSong else { return }
        
        // 先重置状态
        self.lyrics = []
        self.currentLyric = song.title // 加载前先显示歌名
        
        // 异步获取
        lyricsManager.fetchLyrics(for: song, duration: duration) { [weak self] parsed, updatedSong in
            DispatchQueue.main.async {
                // 必须检查当前播放的歌是否还是当初请求的那首（防止用户快速连续切歌）
                guard let self = self, self.currentSong?.id == song.id else { return }
                
                self.lyrics = parsed
                // 如果歌词里包含了偏移修正后的新 Song 对象，更新之
                if let newSong = updatedSong {
                    self.currentSong = newSong
                }
            }
        }
    }
}
