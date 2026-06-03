//
//  PhantomGuard.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/9.
//

import AppKit
import Observation

@MainActor
@Observable
class PhantomGuard {
    static let shared = PhantomGuard()
    
    // MARK: - 用户偏好设置 (保持计算属性，确保与 Preferences 同步)
    var showMenuBarLyrics: Bool {
        get { Preferences.shared.showMenuBarLyrics }
        set { Preferences.shared.showMenuBarLyrics = newValue }
    }
    var showFloatingWindow: Bool {
        get { Preferences.shared.showFloatingWindow }
        set { Preferences.shared.showFloatingWindow = newValue }
    }
    
    // MARK: - 全局状态
    var isAppleMusicRunning: Bool = false
    var playbackState: String = "Stopped"
    
    var currentLyrics: [LyricLine] = []
    var currentLineIndex: Int? = nil
    var currentPlaybackTime: Double = 0.0
    var currentTrackLocation: String = ""
    var currentTrackTitle: String = ""
    var currentTrackArtist: String = ""
    
    @ObservationIgnored private let musicMonitor = MusicMonitor()
    @ObservationIgnored private let menuBarManager = MenuBarManager()
    @ObservationIgnored private let lyricsWindowManager = LyricsWindowManager()
    
    // MARK: - 时间齿轮
    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var lastMusicAccessError: String?
    @ObservationIgnored private var lastTickDate: Date?
    @ObservationIgnored private var lastCalibrationDate: Date?
    
    private init() {
        setupBindings()
        setupMenuBarBindings()
    }
    
    deinit {
        musicMonitor.stop()
    }
    
    private func setupBindings() {
        // 当监听到 Music 启动时，同步执行 UI 唤醒
        musicMonitor.onMusicAppLaunched = { [weak self] in
            guard let self = self else { return }
            print("🚀 监测到 Apple Music 启动")
            self.isAppleMusicRunning = true
            
            // 立即唤醒 UI
            self.refreshUIComponents()
        }
        
        musicMonitor.onMusicAppTerminated = { [weak self] in
            guard let self = self else { return }
            print("⚠️ 监测到 Apple Music 已退出，Soloist 进入休眠模式")
            
            self.stopTimeGear()
            self.isAppleMusicRunning = false
            self.playbackState = "Stopped"
            self.currentLyrics = []
            self.currentLineIndex = nil
            self.currentTrackLocation = ""
            self.currentTrackTitle = ""
            self.currentTrackArtist = ""

            self.lyricsWindowManager.hide()
            self.menuBarManager.unmount()
        }
        
        musicMonitor.onTrackChanged = { [weak self] event in
            guard let self = self else { return }
            
            let location = event.location
            let isRealTrackChange = (self.currentTrackLocation != location && !location.isEmpty)
            
            self.playbackState = event.state.rawValue
            
            if event.state == .playing {
                let displayName = self.resolveDisplayName(from: event, location: location)
                if isRealTrackChange || self.currentTrackTitle != displayName {
                    print("📁 切歌重载！旧: \(self.currentTrackLocation) -> 新: \(location)")
                    self.currentTrackLocation = location
                    self.currentTrackTitle = displayName
                    self.currentTrackArtist = self.resolveArtistName(from: event)
                    switch LyricEngine.loadLyrics(for: location) {
                    case .success(let lyrics):
                        self.currentLyrics = lyrics
                        self.currentLineIndex = nil
                        self.menuBarManager.updateLyricsTitle(text: nil)
                    case .failure(let error):
                        print("⚠️ [PhantomGuard] 歌词加载失败: \(error.localizedDescription)")
                        self.currentLyrics = []
                        self.currentLineIndex = nil
                        self.menuBarManager.updateLyricsTitle(text: nil)
                    }
                }
                self.refreshMenuBarPlaybackState()
                self.startTimeGear()
            } else if event.state == .paused {
                self.refreshMenuBarPlaybackState()
            } else {
                self.stopTimeGear()
                self.refreshMenuBarPlaybackState()
            }
        }
    }

    private func setupMenuBarBindings() {
        menuBarManager.onToggleMenuBarLyrics = { [weak self] in
            guard let self = self else { return }
            self.showMenuBarLyrics.toggle()
            self.menuBarManager.syncState(
                showMenuBarLyrics: self.showMenuBarLyrics,
                showFloatingWindow: self.showFloatingWindow,
                isWindowLocked: Preferences.shared.isWindowLocked
            )
            if !self.showMenuBarLyrics {
                self.menuBarManager.clearLyricsTitle()
            }
        }

        menuBarManager.onToggleFloatingWindow = { [weak self] in
            guard let self = self else { return }
            self.showFloatingWindow.toggle()
            self.menuBarManager.syncState(
                showMenuBarLyrics: self.showMenuBarLyrics,
                showFloatingWindow: self.showFloatingWindow,
                isWindowLocked: Preferences.shared.isWindowLocked
            )
            if self.showFloatingWindow {
                self.lyricsWindowManager.show()
            } else {
                self.lyricsWindowManager.hide()
            }
        }

        menuBarManager.onTogglePlayPause = { [weak self] in
            guard let self = self else { return }
            switch MusicController.togglePlayPause() {
            case .success:
                self.playbackState = (self.playbackState == "Playing") ? "Paused" : "Playing"
                self.refreshMenuBarPlaybackState()
                break
            case .failure(let error):
                print("⚠️ [PhantomGuard] 播放/暂停失败: \(error.localizedDescription)")
            }
        }

        menuBarManager.onNextTrack = { [weak self] in
            guard let self = self else { return }
            switch MusicController.nextTrack() {
            case .success:
                self.refreshMenuBarPlaybackState()
                break
            case .failure(let error):
                print("⚠️ [PhantomGuard] 下一首失败: \(error.localizedDescription)")
            }
        }

        menuBarManager.onPreviousTrack = { [weak self] in
            guard let self = self else { return }
            switch MusicController.previousTrack() {
            case .success:
                self.refreshMenuBarPlaybackState()
                break
            case .failure(let error):
                print("⚠️ [PhantomGuard] 上一首失败: \(error.localizedDescription)")
            }
        }

        menuBarManager.onToggleLock = {
            Preferences.shared.isWindowLocked.toggle()
            self.menuBarManager.syncState(
                showMenuBarLyrics: self.showMenuBarLyrics,
                showFloatingWindow: self.showFloatingWindow,
                isWindowLocked: Preferences.shared.isWindowLocked
            )
            self.lyricsWindowManager.updateLockState()
        }

        menuBarManager.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - UI 自动唤醒逻辑
    
    /// 统一处理菜单栏和悬浮窗的显示，解决自动启动不出现的 Bug
    private func refreshUIComponents() {
        self.menuBarManager.mount()
        self.menuBarManager.syncState(
            showMenuBarLyrics: self.showMenuBarLyrics,
            showFloatingWindow: self.showFloatingWindow,
            isWindowLocked: Preferences.shared.isWindowLocked
        )
        self.refreshMenuBarPlaybackState()
        if self.showFloatingWindow {
            self.lyricsWindowManager.show()
        } else {
            self.lyricsWindowManager.hide()
        }
    }
    
    // MARK: - 时间同步逻辑
    
    private func startTimeGear() {
        stopTimeGear()
        if let realTime = currentPlaybackTimeFromMusic() {
            self.currentPlaybackTime = realTime
        }
        lastTickDate = Date()
        lastCalibrationDate = Date()
        
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer = displayTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimeGear() {
        displayTimer?.invalidate()
        displayTimer = nil
        lastTickDate = nil
        lastCalibrationDate = nil
    }
    
    private func tick() {
        guard playbackState == "Playing" else { return }
        
        let now = Date()
        if let lastTickDate {
            let delta = now.timeIntervalSince(lastTickDate)
            if delta > 0 {
                currentPlaybackTime += delta
            }
        }
        self.lastTickDate = now
        
        if let lastCalibrationDate,
           now.timeIntervalSince(lastCalibrationDate) >= 5.0 {
            self.lastCalibrationDate = now
            if let realTime = currentPlaybackTimeFromMusic(),
               abs(realTime - currentPlaybackTime) > 0.35 {
                self.currentPlaybackTime = realTime
            }
        }
        
        if !currentLyrics.isEmpty {
            let newIndex = LyricEngine.findCurrentLineIndex(in: currentLyrics, at: currentPlaybackTime)
            if newIndex != currentLineIndex {
                currentLineIndex = newIndex
                if let idx = newIndex {
                    let lyricText = currentLyrics[idx].text
                    
                    if showMenuBarLyrics {
                        menuBarManager.updateLyricsTitle(text: lyricText)
                    } else {
                        menuBarManager.updateLyricsTitle(text: nil)
                    }
                }
            }
        }
    }
    
    func startSystem() {
        musicMonitor.start()
        checkInitialState()
    }
    
    private func checkInitialState() {
        let apps = NSWorkspace.shared.runningApplications
        if apps.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            isAppleMusicRunning = true
            
            refreshUIComponents()
            
            if let _ = currentPlaybackTimeFromMusic() {
                playbackState = "Playing"
                startTimeGear()
            }
        }
    }
    
    func handleReopen() {
        if !isAppleMusicRunning {
            menuBarManager.mount()
            menuBarManager.syncState(
                showMenuBarLyrics: self.showMenuBarLyrics,
                showFloatingWindow: self.showFloatingWindow,
                isWindowLocked: Preferences.shared.isWindowLocked
            )
            refreshMenuBarPlaybackState()
        }
    }

    private func refreshMenuBarPlaybackState() {
        menuBarManager.syncPlaybackState(
            isAppleMusicRunning: isAppleMusicRunning,
            isPlaying: playbackState == "Playing",
            displayText: playbackMenuText()
        )
    }

    private func playbackMenuText() -> String {
        if !isAppleMusicRunning {
            return "Apple Music 未运行"
        }

        switch playbackState {
        case "Playing":
            return menuBarTrackText()
        case "Paused":
            return menuBarTrackText()
        default:
            return "未在播放"
        }
    }

    private func menuBarTrackText() -> String {
        let title = currentTrackTitle.isEmpty ? "未知歌曲" : currentTrackTitle
        let artist = currentTrackArtist.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !artist.isEmpty else {
            return title
        }

        return "\(title) - \(artist)"
    }
    
    private func resolveDisplayName(from event: MusicMonitor.TrackEvent, location: String) -> String {
        if let title = event.title, !title.isEmpty {
            return title
        }
        
        if let playerName = event.playerName, !playerName.isEmpty {
            return playerName
        }
        
        if let url = URL(string: location) {
            return url.deletingPathExtension().lastPathComponent
        }
        
        return location.isEmpty ? "未知歌曲" : location
    }

    private func resolveArtistName(from event: MusicMonitor.TrackEvent) -> String {
        if let artist = event.artist, !artist.isEmpty {
            return artist
        }

        if let playerName = event.playerName, !playerName.isEmpty {
            return playerName
        }

        return ""
    }
    
    private func currentPlaybackTimeFromMusic() -> Double? {
        switch MusicController.readCurrentPosition() {
        case .success(let realTime):
            lastMusicAccessError = nil
            return realTime
        case .failure(let error):
            let message = error.description
            if lastMusicAccessError != message {
                print("⚠️ 读取 Apple Music 播放位置失败：\(message)")
                lastMusicAccessError = message
            }
            return nil
        }
    }
}
