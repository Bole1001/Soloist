//
//  MenuBarManager.swift
//  Soloist
//
//  Created by Bole on 2026/2/4.
//

import SwiftUI
import Combine
import AppKit

class MenuBarManager: NSObject {
    
    // 单例模式，方便 AppDelegate 调用
    static let shared = MenuBarManager()
    
    // 核心组件
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let playerService = AudioPlayerService.shared
    
    // 菜单对象
    private var contextMenu: NSMenu!
    
    // 监控点击事件
    private var eventMonitor: Any?
    
    // 状态开关
    private var showMenuBarLyrics: Bool = false
    
    override init() {
        super.init()
        // 在初始化时读取配置
        self.showMenuBarLyrics = UserDefaults.standard.bool(forKey: "showMenuBarLyrics")
    }
    
    // MARK: - Setup (由 AppDelegate 调用)
    
    func setup() {
        // 1. 创建状态栏 Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.imagePosition = .imageTrailing
            button.title = ""
            
            button.action = #selector(menuBarClickHandler)
            button.target = self // 指向自己
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. 初始化菜单
        setupMenu()
        
        // 3. 绑定数据监听
        setupBindings()
        
        // 4. 监听设置通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // 5. 初始刷新
        updateMenuBarAppearance(lyric: playerService.currentLyric, isPlaying: playerService.isPlaying)
    }
    
    // MARK: - Click Logic
    
    @objc func menuBarClickHandler(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem?.menu = contextMenu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleMainWindow()
        }
    }
    
    func toggleMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.title == "Soloist" }) else { return }
        
        if window.isVisible && window.isKeyWindow {
            closeMainWindow()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            startEventMonitor()
        }
    }

    func closeMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.title == "Soloist" }) else { return }
        window.orderOut(nil)
        stopEventMonitor()
    }
    
    // 公开给 AppDelegate 使用的方法
    @objc func openMainWindow() {
        let window = NSApp.windows.first(where: { $0.title == "Soloist" })
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Handle Settings Change
    
    @objc func handleSettingsChange() {
        // 1. 重新读取最新的开关状态
        let newShowState = UserDefaults.standard.bool(forKey: "showMenuBarLyrics")
        
        // 2. 如果状态确实变了，才去刷新 UI
        if self.showMenuBarLyrics != newShowState {
            self.showMenuBarLyrics = newShowState
            
            // 3. 确保在主线程刷新
            DispatchQueue.main.async {
                self.updateMenuBarAppearance(
                    lyric: self.playerService.currentLyric,
                    isPlaying: self.playerService.isPlaying
                )
            }
        }
        DispatchQueue.main.async {
            self.updateMenuState()
        }
    }
    
    // MARK: - Setup Menu
    
    private func setupMenu() {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "显示主界面", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        
        let infoItem = NSMenuItem(title: playerService.currentSong?.title ?? "Soloist", action: nil, keyEquivalent: "")
        infoItem.tag = 102
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        
        let playItem = NSMenuItem(title: "播放/暂停", action: #selector(playPause), keyEquivalent: " ")
        playItem.target = self
        menu.addItem(playItem)
        
        let prevItem = NSMenuItem(title: "上一首", action: #selector(prevSong), keyEquivalent: "")
        prevItem.target = self
        menu.addItem(prevItem)
        
        let nextItem = NSMenuItem(title: "下一首", action: #selector(nextSong), keyEquivalent: "")
        nextItem.target = self
        menu.addItem(nextItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 1. 桌面悬浮歌词
        let desktopItem = NSMenuItem(title: "桌面悬浮歌词", action: #selector(toggleDesktopLyrics), keyEquivalent: "T")
        desktopItem.tag = 103
        desktopItem.target = self
        menu.addItem(desktopItem)
        
        // 2. 状态栏歌词
        let toggleItem = NSMenuItem(title: "状态栏歌词", action: #selector(toggleLyrics), keyEquivalent: "Y")
        toggleItem.tag = 101
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        // 3. 触控栏歌词
        if TouchBarManager.shared.isFeatureAvailable {
            let tbItem = NSMenuItem(title: "触控栏歌词", action: #selector(toggleTouchBar), keyEquivalent: "U")
            tbItem.keyEquivalentModifierMask = [.command, .shift]
            tbItem.tag = 104
            tbItem.target = self
            menu.addItem(tbItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出 Soloist", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.contextMenu = menu
        
        updateMenuState()
    }
    
    private func updateMenuState() {
        guard let menu = self.contextMenu else { return }
        
        // 1. 更新状态栏歌词勾选
        if let item = menu.item(withTag: 101) {
            let isOn = UserDefaults.standard.bool(forKey: "showMenuBarLyrics")
            item.state = isOn ? .on : .off
        }
        
        // 2. 更新桌面歌词勾选
        if let item = menu.item(withTag: 103) {
            let isOn = UserDefaults.standard.bool(forKey: "showDesktopLyrics")
            item.state = isOn ? .on : .off
        }
        
        // 3. 更新触控栏歌词勾选
        if let item = menu.item(withTag: 104) {
            let isOn = UserDefaults.standard.bool(forKey: "showTouchBarLyrics")
            item.state = isOn ? .on : .off
        }
    }
    
    // MARK: - Bindings & Updates
    
    private func setupBindings() {
        playerService.$currentLyric
            .combineLatest(playerService.$isPlaying, playerService.$currentSong)
            .sink { [weak self] (lyric, isPlaying, song) in
                self?.updateMenuBarAppearance(lyric: lyric, isPlaying: isPlaying)
                self?.updateMenuContent(song: song)
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarAppearance(lyric: String, isPlaying: Bool) {
        guard let button = statusItem?.button else { return }
        
        // 判断条件：开关开启 && 有歌词
        if showMenuBarLyrics && !lyric.isEmpty {
            button.title = String(lyric.prefix(20))
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            button.title = ""
        }
    }
    
    private func updateMenuContent(song: Song?) {
        if let infoItem = contextMenu.item(withTag: 102) {
            infoItem.title = song?.title ?? "Soloist"
        }
    }
    
    // MARK: - Actions
    
    @objc func toggleLyrics() {
        showMenuBarLyrics.toggle()
        UserDefaults.standard.set(showMenuBarLyrics, forKey: "showMenuBarLyrics")
        updateMenuBarAppearance(lyric: playerService.currentLyric, isPlaying: playerService.isPlaying)
        updateMenuState()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc func toggleTouchBar() {
        var isOn = UserDefaults.standard.bool(forKey: "showTouchBarLyrics")
        isOn.toggle()
        UserDefaults.standard.set(isOn, forKey: "showTouchBarLyrics")
        
        if isOn {
            TouchBarManager.shared.present()
        } else {
            TouchBarManager.shared.dismiss()
        }
        
        updateMenuState()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc func toggleDesktopLyrics() {
        DesktopLyricsController.shared.toggle()
        let newState = DesktopLyricsController.shared.isShow
        UserDefaults.standard.set(newState, forKey: "showDesktopLyrics")
        updateMenuState()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc func playPause() { playerService.togglePlayPause() }
    @objc func prevSong() { playerService.previous() }
    @objc func nextSong() { playerService.next() }
    @objc func quitApp() { NSApp.terminate(nil) }
    
    // MARK: - Event Monitor Logic

    private func startEventMonitor() {
        // 防止重复添加
        if eventMonitor != nil { return }
        
        // 监听全局点击（App 以外的点击，比如桌面、其他App）
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // 当监测到外部点击时，关闭窗口
            self?.closeMainWindow()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
