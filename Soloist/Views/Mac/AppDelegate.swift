//
//  AppDelegate.swift
//  Soloist
//
//  Created by Bole on 2026/2/2.
//

import SwiftUI
import Combine

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 核心组件
    var statusItem: NSStatusItem?
    var cancellables = Set<AnyCancellable>()
    let playerService = AudioPlayerService.shared
    
    // 菜单对象
    var contextMenu: NSMenu!
    
    // 状态开关
    var showMenuBarLyrics: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 创建状态栏 Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.imagePosition = .imageTrailing
            button.title = ""
            
            button.action = #selector(menuBarClickHandler)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. 初始化菜单
        setupMenu()
        
        // 3. 绑定数据监听
        setupBindings()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: UserDefaults.didChangeNotification, // 监听设置变化
            object: nil
        )
        
        self.showMenuBarLyrics = UserDefaults.standard.bool(forKey: "showMenuBarLyrics")
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
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - App Lifecycle
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { toggleMainWindow() }
        return true
    }
    
    // MARK: - Handle Settings Change
    
    /// 当你在主界面点击“栏”字时，会触发这个方法
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
    
    func setupMenu() {
            let menu = NSMenu()
            
            let openItem = NSMenuItem(title: "显示主界面", action: #selector(openMainWindow), keyEquivalent: "o")
            menu.addItem(openItem)
            menu.addItem(NSMenuItem.separator())
            
            let infoItem = NSMenuItem(title: playerService.currentSong?.title ?? "Soloist", action: nil, keyEquivalent: "")
            infoItem.tag = 102
            infoItem.isEnabled = false
            menu.addItem(infoItem)
            
            let playItem = NSMenuItem(title: "播放/暂停", action: #selector(playPause), keyEquivalent: " ")
            menu.addItem(playItem)
            
            menu.addItem(NSMenuItem(title: "上一首", action: #selector(prevSong), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "下一首", action: #selector(nextSong), keyEquivalent: ""))
            
            menu.addItem(NSMenuItem.separator())
            
            // 1. 桌面悬浮歌词 (修改：添加变量、Tag)
            let desktopItem = NSMenuItem(title: "桌面悬浮歌词", action: #selector(toggleDesktopLyrics), keyEquivalent: "T")
            desktopItem.tag = 103
            menu.addItem(desktopItem)
            
            // 2. 状态栏歌词 (原有)
            let toggleItem = NSMenuItem(title: "状态栏歌词", action: #selector(toggleLyrics), keyEquivalent: "Y")
            toggleItem.tag = 101
            menu.addItem(toggleItem)
            
            // 3. 触控栏歌词 (修改：添加 Tag)
            if TouchBarManager.shared.isFeatureAvailable {
                let tbItem = NSMenuItem(title: "触控栏歌词", action: #selector(toggleTouchBar), keyEquivalent: "U")
                tbItem.keyEquivalentModifierMask = [.command, .shift]
                tbItem.tag = 104 // ✨ 设置 Tag 方便查找
                menu.addItem(tbItem)
            }
            
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "退出 Soloist", action: #selector(quitApp), keyEquivalent: "q"))
            
            self.contextMenu = menu
            
            updateMenuState()
        }
        
        func updateMenuState() {
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
    
    func setupBindings() {
        playerService.$currentLyric
            .combineLatest(playerService.$isPlaying, playerService.$currentSong)
            .sink { [weak self] (lyric, isPlaying, song) in
                self?.updateMenuBarAppearance(lyric: lyric, isPlaying: isPlaying)
                self?.updateMenuContent(song: song)
            }
            .store(in: &cancellables)
    }
    
    func updateMenuBarAppearance(lyric: String, isPlaying: Bool) {
        guard let button = statusItem?.button else { return }
        
        // 判断条件：开关开启 && 正在播放 && 有歌词
        if showMenuBarLyrics && isPlaying && !lyric.isEmpty {
            button.title = String(lyric.prefix(20))
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            button.title = ""
        }
    }
    
    func updateMenuContent(song: Song?) {
        if let infoItem = contextMenu.item(withTag: 102) {
            infoItem.title = song?.title ?? "Soloist"
        }
    }
    
    // MARK: - Actions
    
    @objc func openMainWindow() {
        let window = NSApp.windows.first(where: { $0.title == "Soloist" })
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    // 1. 状态栏歌词点击
    @objc func toggleLyrics() {
        showMenuBarLyrics.toggle()
        
        // 保存设置
        UserDefaults.standard.set(showMenuBarLyrics, forKey: "showMenuBarLyrics")
        
        // 刷新 UI
        updateMenuBarAppearance(lyric: playerService.currentLyric, isPlaying: playerService.isPlaying)
        updateMenuState() // 刷新勾选
        
        // 通知主界面
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }

    // 2. 触控栏歌词点击
    @objc func toggleTouchBar() {
        // 读取 -> 取反 -> 保存
        var isOn = UserDefaults.standard.bool(forKey: "showTouchBarLyrics")
        isOn.toggle()
        UserDefaults.standard.set(isOn, forKey: "showTouchBarLyrics")
        
        // 执行实际显示/隐藏
        if isOn {
            TouchBarManager.shared.present()
        } else {
            TouchBarManager.shared.dismiss()
        }
        
        // 刷新勾选 & 通知主界面
        updateMenuState()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }

    // 3. 桌面悬浮歌词点击
    @objc func toggleDesktopLyrics() {
        // 执行切换
        DesktopLyricsController.shared.toggle()
        
        // 保存当前实际状态
        let newState = DesktopLyricsController.shared.isShow
        UserDefaults.standard.set(newState, forKey: "showDesktopLyrics")
        
        // 刷新勾选 & 通知主界面
        updateMenuState()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc func playPause() { playerService.togglePlayPause() }
    @objc func prevSong() { playerService.previous() }
    @objc func nextSong() { playerService.next() }
    @objc func quitApp() { NSApp.terminate(nil) }
}
#endif
