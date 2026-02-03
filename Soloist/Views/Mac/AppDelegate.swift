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
    
    // 菜单对象 (现在作为一个属性保存，而不是直接赋给 statusItem)
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
            
            // ✨✨✨ 核心修改：手动接管点击事件 ✨✨✨
            button.action = #selector(menuBarClickHandler)
            button.target = self
            
            // 关键：告诉系统，我要同时监听“左键抬起”和“右键抬起”
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // 2. 初始化菜单 (存入 contextMenu 变量，先不显示)
        setupMenu()
        
        // 3. 绑定数据监听
        setupBindings()
    }
    
    // MARK: - ✨ New Click Logic
    
    @objc func menuBarClickHandler(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        // 判断是否是 右键点击 或者 按住 Control 点击
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // 👉 右键：弹出菜单
            statusItem?.menu = contextMenu // 临时挂载菜单
            statusItem?.button?.performClick(nil) // 触发系统弹窗
            statusItem?.menu = nil // 弹完后立即卸载，为下次左键做准备
        } else {
            // 👉 左键：切换主窗口显示/隐藏
            toggleMainWindow()
        }
    }
    
    // 切换主窗口逻辑：如果显示就隐藏，如果隐藏就显示
    func toggleMainWindow() {
        // 获取主窗口
        guard let window = NSApp.windows.first(where: { $0.title == "Soloist" }) else { return }
        
        if window.isVisible && window.isKeyWindow {
            // 如果窗口正在最前显示，则隐藏 (类似很多工具软件的逻辑)
            window.orderOut(nil)
        } else {
            // 否则，前置显示并激活 App
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - App Lifecycle (保留你刚才加的保活逻辑)
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            toggleMainWindow()
        }
        return true
    }
    
    // MARK: - Setup Menu
    
    // 配置下拉菜单 (逻辑不变，只是最后不赋值给 statusItem.menu)
    func setupMenu() {
        let menu = NSMenu()
        
        // 1. Navigation (左键已经能打开主窗口了，这个菜单项可以留着备用，或者去掉)
        let openItem = NSMenuItem(title: "显示主界面", action: #selector(openMainWindow), keyEquivalent: "o")
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Toggle Lyrics
        let lyricsTitle = showMenuBarLyrics ? "关闭状态栏歌词" : "开启状态栏歌词"
        let toggleItem = NSMenuItem(title: lyricsTitle, action: #selector(toggleLyrics), keyEquivalent: "")
        toggleItem.tag = 101
        menu.addItem(toggleItem)
        
        // 3. TouchBar
        if TouchBarManager.shared.isFeatureAvailable {
            let tbItem = NSMenuItem(title: "开启/关闭 触控栏歌词", action: #selector(toggleTouchBar), keyEquivalent: "T")
            tbItem.keyEquivalentModifierMask = [.command, .shift]
            menu.addItem(tbItem)
        }
        
        // 4. Player Controls
        let infoItem = NSMenuItem(title: playerService.currentSong?.title ?? "Soloist", action: nil, keyEquivalent: "")
        infoItem.tag = 102
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        
        let playItem = NSMenuItem(title: "播放/暂停", action: #selector(playPause), keyEquivalent: " ")
        menu.addItem(playItem)
        
        menu.addItem(NSMenuItem(title: "上一首", action: #selector(prevSong), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "下一首", action: #selector(nextSong), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. System Features
        menu.addItem(NSMenuItem(title: "桌面悬浮歌词", action: #selector(toggleDesktopLyrics), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quit
        menu.addItem(NSMenuItem(title: "退出 Soloist", action: #selector(quitApp), keyEquivalent: "q"))
        
        // ✨ 改动：保存到 self.contextMenu，而不是 statusItem.menu
        self.contextMenu = menu
        
        // 初始更新菜单状态
        if let item = menu.item(withTag: 101) {
            let isOn = UserDefaults.standard.bool(forKey: "showMenuBarLyrics") // 这里简化读取，实际可以用变量
            item.state = isOn ? .on : .off
        }
    }
    
    // MARK: - Bindings & Updates (保持不变)
    
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
        
        if showMenuBarLyrics && isPlaying && !lyric.isEmpty {
            button.title = String(lyric.prefix(20))
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            button.title = ""
        }
    }
    
    func updateMenuContent(song: Song?) {
        // ✨ 改动：从 contextMenu 获取 item
        if let infoItem = contextMenu.item(withTag: 102) {
            infoItem.title = song?.title ?? "Soloist"
        }
    }
    
    // MARK: - Actions
    
    @objc func openMainWindow() {
        // 复用 toggle 逻辑，强制显示
        let window = NSApp.windows.first(where: { $0.title == "Soloist" })
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    @objc func toggleLyrics() {
        showMenuBarLyrics.toggle()
        // 更新菜单文字
        if let item = contextMenu.item(withTag: 101) {
            item.title = showMenuBarLyrics ? "关闭状态栏歌词" : "开启状态栏歌词"
        }
        updateMenuBarAppearance(lyric: playerService.currentLyric, isPlaying: playerService.isPlaying)
    }
    
    // 其他 Action 保持不变...
    @objc func toggleTouchBar() { TouchBarManager.shared.toggle() }
    @objc func playPause() { playerService.togglePlayPause() }
    @objc func prevSong() { playerService.previous() }
    @objc func nextSong() { playerService.next() }
    @objc func toggleDesktopLyrics() { DesktopLyricsController.shared.toggle() }
    @objc func quitApp() { NSApp.terminate(nil) }
}
#endif
