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
    
    // 状态开关 (默认关闭，每次重启重置)
    var showMenuBarLyrics: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 创建状态栏 Item (长度可变)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // 设置图标
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true // 适应黑白/深色模式
            
            // 核心设置：图标在右，文字在左
            button.imagePosition = .imageTrailing
            
            // 初始标题为空
            button.title = ""
        }
        
        // 2. 初始化菜单
        setupMenu()
        
        // 3. 绑定数据监听
        setupBindings()
    }
    
    // 配置下拉菜单
    func setupMenu() {
        let menu = NSMenu()
        
        // Navigation
        let openItem = NSMenuItem(title: "显示主界面", action: #selector(openMainWindow), keyEquivalent: "o")
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle Lyrics
        let lyricsTitle = showMenuBarLyrics ? "关闭状态栏歌词" : "开启状态栏歌词"
        let toggleItem = NSMenuItem(title: lyricsTitle, action: #selector(toggleLyrics), keyEquivalent: "")
        toggleItem.tag = 101 // 设置 tag 以便后续查找更新
        menu.addItem(toggleItem)
        
        // TouchBar (Optional)
        if TouchBarManager.shared.isFeatureAvailable {
            let tbItem = NSMenuItem(title: "开启/关闭 触控栏歌词", action: #selector(toggleTouchBar), keyEquivalent: "T")
            tbItem.keyEquivalentModifierMask = [.command, .shift]
            menu.addItem(tbItem)
        }
        
        // Player Controls (Menu Display)
        // 显示当前歌曲信息的不可点击项
        let infoItem = NSMenuItem(title: playerService.currentSong?.title ?? "Soloist", action: nil, keyEquivalent: "")
        infoItem.tag = 102
        infoItem.isEnabled = false // 仅展示
        menu.addItem(infoItem)
        
        let playItem = NSMenuItem(title: "播放/暂停", action: #selector(playPause), keyEquivalent: " ")
        menu.addItem(playItem)
        
        menu.addItem(NSMenuItem(title: "上一首", action: #selector(prevSong), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "下一首", action: #selector(nextSong), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // System Features
        menu.addItem(NSMenuItem(title: "桌面悬浮歌词", action: #selector(toggleDesktopLyrics), keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // Lifecycle
        menu.addItem(NSMenuItem(title: "退出 Soloist", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // 绑定 PlayerService 的数据变化
    func setupBindings() {
        // 监听歌词变化、播放状态变化
        playerService.$currentLyric
            .combineLatest(playerService.$isPlaying, playerService.$currentSong)
            .sink { [weak self] (lyric, isPlaying, song) in
                self?.updateMenuBarAppearance(lyric: lyric, isPlaying: isPlaying)
                self?.updateMenuContent(song: song)
            }
            .store(in: &cancellables)
    }
    
    // 更新状态栏上的文字 (Bar)
    func updateMenuBarAppearance(lyric: String, isPlaying: Bool) {
        guard let button = statusItem?.button else { return }
        
        if showMenuBarLyrics && isPlaying && !lyric.isEmpty {
            // 有歌词：设置截断后的文字
            // 使用等宽数字字体防止时间跳动时的抖动
            button.title = String(lyric.prefix(20))
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        } else {
            // 无歌词/未开启：清空文字，图标会自动归位
            button.title = ""
        }
    }
    
    // 更新下拉菜单里的内容 (Menu)
    func updateMenuContent(song: Song?) {
        guard let menu = statusItem?.menu else { return }
        
        // 更新歌曲信息项
        if let infoItem = menu.item(withTag: 102) {
            infoItem.title = song?.title ?? "Soloist"
        }
    }
    
    // MARK: - Actions
    
    @objc func openMainWindow() {
        // 激活应用并前置窗口
        NSApp.activate(ignoringOtherApps: true)
        // 查找主窗口并显示
        if let window = NSApp.windows.first(where: { $0.title == "Soloist" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func toggleLyrics() {
        showMenuBarLyrics.toggle()
        
        // 更新菜单项文字
        if let item = statusItem?.menu?.item(withTag: 101) {
            item.title = showMenuBarLyrics ? "关闭状态栏歌词" : "开启状态栏歌词"
        }
        
        // 立即触发一次 UI 更新
        updateMenuBarAppearance(lyric: playerService.currentLyric, isPlaying: playerService.isPlaying)
    }
    
    @objc func toggleTouchBar() { TouchBarManager.shared.toggle() }
    @objc func playPause() { playerService.togglePlayPause() }
    @objc func prevSong() { playerService.previous() }
    @objc func nextSong() { playerService.next() }
    @objc func toggleDesktopLyrics() { DesktopLyricsController.shared.toggle() }
    @objc func quitApp() { NSApp.terminate(nil) }
}
#endif
