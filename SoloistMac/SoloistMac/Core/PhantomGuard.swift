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
    
    @ObservationIgnored private let musicMonitor = MusicMonitor()
    @ObservationIgnored private let menuBarManager = MenuBarManager.shared
    
    // MARK: - 时间齿轮
    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var syncCounter = 0
    
    private init() {
        setupBindings()
        
        // 注册应用终止系统监听
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppTermination(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
        
        musicMonitor.onTrackChanged = { [weak self] state, location in
            guard let self = self else { return }
            
            let isRealTrackChange = (self.currentTrackLocation != location && !location.isEmpty)
            
            self.playbackState = state
            
            if state == "Playing" {
                if isRealTrackChange {
                    print("📁 切歌重载！旧: \(self.currentTrackLocation) -> 新: \(location)")
                    self.currentTrackLocation = location
                    
                    if let url = URL(string: location) {
                        let songName = url.deletingPathExtension().lastPathComponent
                        self.menuBarManager.updateMenuInfo(text: "\(songName)")
                    }
                    
                    self.currentLyrics = LyricEngine.loadLyrics(for: location)
                    self.currentLineIndex = nil
                }
                
                self.startTimeGear()
            } else {
                self.stopTimeGear()
                self.menuBarManager.updateMenuInfo(text: "⏸️ 已暂停")
            }
        }
    }
    
    // MARK: - UI 自动唤醒逻辑
    
    /// 统一处理菜单栏和悬浮窗的显示，解决自动启动不出现的 Bug
    private func refreshUIComponents() {
        // 1. 挂载菜单栏
        self.menuBarManager.mount()
        
        // 2. 如果开启了悬浮窗，自动显示
        if self.showFloatingWindow {
            // 给系统 200ms 缓冲，确保 UI 线程完全就绪
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                LyricsWindowManager.shared.show()
            }
        }
    }
    
    // MARK: - 进程生命周期监听
    @objc private func handleAppTermination(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            if app.bundleIdentifier == "com.apple.Music" {
                print("⚠️ 监测到 Apple Music 已退出，Soloist 进入休眠模式")
                
                self.stopTimeGear()
                self.isAppleMusicRunning = false
                self.playbackState = "Stopped"
                self.currentLyrics = []
                self.currentLineIndex = nil
                self.currentTrackLocation = ""
                
                DispatchQueue.main.async {
                    LyricsWindowManager.shared.hide()
                    self.menuBarManager.unmount()
                }
            }
        }
    }
    
    // MARK: - 时间同步逻辑
    
    private func startTimeGear() {
        stopTimeGear()
        if let realTime = MusicController.getCurrentPosition() {
            self.currentPlaybackTime = realTime
        }
        
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
        syncCounter = 0
    }
    
    private func tick() {
        guard playbackState == "Playing" else { return }
        
        currentPlaybackTime += 0.1
        syncCounter += 1
        
        if syncCounter >= 10 {
            syncCounter = 0
            if let realTime = MusicController.getCurrentPosition() {
                if abs(realTime - currentPlaybackTime) > 0.5 {
                    self.currentPlaybackTime = realTime
                }
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
            
            if let _ = MusicController.getCurrentPosition() {
                playbackState = "Playing"
                startTimeGear()
            }
        }
    }
    
    func handleReopen() {
        if !isAppleMusicRunning {
            menuBarManager.mount()
        }
    }
}
