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
    static let shared = AudioPlayerService()
    
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
            playlist.isShuffleMode = isShuffleMode
            if isShuffleMode {
                // 这里也要改：传入当前歌曲 currentSong
                playlist.reshuffle(keepCurrentAtTop: currentSong)
            }
        }
    }
    
    // 循环模式开关
    @Published var isLoopMode: Bool = true
    
    // 播放队列
    private let playlist = PlaylistManager()
    
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
            guard let song = currentSong else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                return
            }
            
            // --- 1. 先设置基础文字信息 (同步执行，立即生效) ---
            // 这样用户切歌时，控制中心的名字会瞬间变化，不会有延迟
            var info: [String: Any] = [
                MPMediaItemPropertyTitle: song.title,
                MPMediaItemPropertyArtist: song.artist,
                MPMediaItemPropertyPlaybackDuration: duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: player?.currentTime ?? 0,
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
            ]
            
            // 先把文字推送到系统
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            
            // --- 2. 后台异步加载封面 ---
            // 这就是我们“去内存化”的核心：用的时候再去硬盘读
            Task {
                // 调用我们新写的工具类
                if let data = await ArtworkLoader.loadArtwork(for: song) {
                    
                    #if os(macOS)
                    if let nsImage = NSImage(data: data) {
                        // 创建系统需要的 Artwork 对象
                        let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in return nsImage }
                        
                        // 取出当前的信息，把图片塞进去
                        var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
                        currentInfo[MPMediaItemPropertyArtwork] = artwork
                        
                        // 再次更新 (这次带图了)
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                    }
                    #else
                    // iOS 逻辑
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
    
    // MARK: - 歌词加载逻辑 (三级降级策略)
        private func loadLyricsForCurrentSong() {
            guard let song = currentSong else { return }
            
            print("📝 [AudioPlayer] 开始加载歌词: \(song.title)")
            
            // 先清空旧歌词，避免显示上一首的
            self.lyrics = []
            self.currentLyric = song.title
            
            // ————————————————
            // 🟢 策略 1: 本地 .lrc 文件 (最高优先级)
            // ————————————————
            if let lrcURL = song.lrcURL {
                let parsed = LRCParser.parse(url: lrcURL)
                if !parsed.isEmpty {
                    print("📂 命中本地 LRC 文件")
                    self.lyrics = parsed
                    return
                }
            }
            
            // ————————————————
            // 🟡 策略 2: 内嵌歌词 (ID3 Tags)
            // ————————————————
            if let embedded = song.embeddedLyrics, !embedded.isEmpty {
                let parsed = LRCParser.parse(content: embedded)
                if !parsed.isEmpty {
                    print("💿 命中 MP3 内嵌歌词")
                    self.lyrics = parsed
                    return
                }
            }
            
            // ————————————————
            // 🔴 策略 3: 联网搜索 (LRCLIB)
            // ————————————————
            
            // 获取时长 (从 AVPlayer 获取，提高搜索准确度)
            let duration = self.player?.duration ?? 0
            
            LyricsFetcher.search(
                title: song.title,
                artist: song.artist,
                album: "", // 专辑名可选，先留空
                duration: duration
            ) { [weak self] lyricString in
                
                // 网络回调在后台线程，必须切回主线程更新 UI
                DispatchQueue.main.async {
                    // ✨✨✨ 关键修复：显式转换类型，解决 "NSObject has no member currentSong" 报错 ✨✨✨
                    guard let self = self else { return }
                    
                    // 确保还没切歌 (防止网速慢，歌都切走了歌词才回来)
                    if self.currentSong?.id == song.id {
                        
                        if let content = lyricString {
                            // 1. 解析下载到的字符串
                            let parsed = LRCParser.parse(content: content)
                            
                            if !parsed.isEmpty {
                                self.lyrics = parsed
                                print("✅ 网络歌词加载成功，准备保存...")
                                
                                // 2. ✨ 保存到本地硬盘 (下次就不用搜了)
                                self.saveLrcFile(content: content, for: song)
                            } else {
                                print("❌ 虽然下载了内容，但解析为空 (可能格式不对)")
                                self.lyrics = []
                            }
                        } else {
                            print("❌ 所有策略均未找到歌词")
                            self.lyrics = [] // 真的没有，保持为空
                        }
                    }
                }
            }
        }

    // MARK: - 文件操作
        
    /// 将歌词保存到当前目录下的 Lyrics 文件夹中
        private func saveLrcFile(content: String, for song: Song) {
            let fileManager = FileManager.default
            
            // 1. 获取 MP3 所在的父目录
            let parentDirectory = song.url.deletingLastPathComponent()
            
            // 2. 构造 Lyrics 文件夹路径
            let lyricsFolderURL = parentDirectory.appendingPathComponent("Lyrics", isDirectory: true)
            
            // 3. 构造最终的文件名 (例如 七里香.lrc)
            let fileName = song.url.deletingPathExtension().lastPathComponent + ".lrc"
            let lrcURL = lyricsFolderURL.appendingPathComponent(fileName)
            
            do {
                // 4. 检查 Lyrics 文件夹是否存在，不存在则创建
                if !fileManager.fileExists(atPath: lyricsFolderURL.path) {
                    try fileManager.createDirectory(at: lyricsFolderURL, withIntermediateDirectories: true, attributes: nil)
                    print("📂 创建歌词文件夹: \(lyricsFolderURL.lastPathComponent)")
                }
                
                // 5. 写入文件
                try content.write(to: lrcURL, atomically: true, encoding: .utf8)
                print("💾 [AudioPlayer] 歌词已归档保存: \(lrcURL.path)")
                
                // 6. 更新内存中的 Song 对象
                // 这样不用重启 App，策略 1 (本地文件) 也能直接找到这个新路径
                DispatchQueue.main.async {
                    if let current = self.currentSong, current.id == song.id {
                        
                        // ✨ 修复：删除了 artworkData 参数
                        let updatedSong = Song(
                            id: current.id,
                            url: current.url,
                            title: current.title,
                            artist: current.artist,
                            // ❌ artworkData: current.artworkData, <-- 删掉这行
                            lrcURL: lrcURL, // 👈 填入新生成的歌词路径
                            embeddedLyrics: current.embeddedLyrics
                        )
                        
                        self.currentSong = updatedSong
                    }
                }
                
            } catch {
                print("⚠️ 保存歌词失败 (可能是没有文件夹创建权限): \(error)")
            }
        }
    
    // MARK: - 公开控制方法
    func play(song: Song, playlist list: [Song]) {
            // 让助手更新列表
            self.playlist.updateList(list)
            if isShuffleMode && playlist.shuffledPlaylist.isEmpty {
                playlist.reshuffle(keepCurrentAtTop: song)
            }
            
            self.currentSong = song
            startPlayback(url: song.url)
            
            // 延迟加载歌词逻辑保持不变...
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadLyricsForCurrentSong()
            }
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
            if let nextSong = playlist.getNextSong(after: currentSong) {
                play(song: nextSong, playlist: playlist.originalPlaylist)
            } else {
                stop()
            }
        }
        
        func previous() {
            // 如果当前播放超过3秒，点上一首通常是重播当前
            if (player?.currentTime ?? 0) > 3.0 {
                player?.currentTime = 0
                updateNowPlayingInfo()
                return
            }
            
            if let prevSong = playlist.getPreviousSong(before: currentSong) {
                play(song: prevSong, playlist: playlist.originalPlaylist)
            }
        }
    
    // MARK: - 内部逻辑
    
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
