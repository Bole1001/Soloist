//
//  MenuBarManager.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import AppKit

@MainActor
class MenuBarManager {
    static let shared = MenuBarManager()
    private var statusItem: NSStatusItem?
    
    // 引入我们的记忆中枢
    private let prefs = Preferences.shared
    
    func mount() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let customImage = NSImage(named: "MenuBarIcon") {
                customImage.isTemplate = true
                button.image = customImage
            }
            button.imagePosition = .imageRight
        }
        constructMenu()
    }
    
    @MainActor
    func showMusicUI(showFloatingWindow: Bool) {
        mount()
        if showFloatingWindow {
            LyricsWindowManager.shared.show()
        }
    }
    
    @MainActor
    func hideMusicUI() {
        LyricsWindowManager.shared.hide()
        unmount()
    }
    
    private func constructMenu() {
        let menu = NSMenu()
        
        // 1. 歌曲信息 (Tag 100)
        let infoItem = NSMenuItem(title: "未在播放", action: nil, keyEquivalent: "")
        infoItem.tag = 100
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. 状态栏开关 (接入记忆)
        let menuBarLyricItem = NSMenuItem(title: "状态栏歌词", action: #selector(toggleMenuBarLyrics), keyEquivalent: "b")
        menuBarLyricItem.target = self
        menuBarLyricItem.state = prefs.showMenuBarLyrics ? .on : .off
        menu.addItem(menuBarLyricItem)
        
        // 3. 悬浮窗开关 (接入记忆)
        let floatingWindowItem = NSMenuItem(title: "桌面悬浮窗", action: #selector(toggleFloatingWindow), keyEquivalent: "w")
        floatingWindowItem.target = self
        floatingWindowItem.state = prefs.showFloatingWindow ? .on : .off
        menu.addItem(floatingWindowItem)
        
        // 4. 新增：锁定开关 (Tag 101)
        let lockItem = NSMenuItem(title: "锁定歌词位置", action: #selector(toggleLock), keyEquivalent: "l")
        lockItem.target = self
        lockItem.state = prefs.isWindowLocked ? .on : .off
        lockItem.isEnabled = prefs.showFloatingWindow
        lockItem.tag = 101
        menu.addItem(lockItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. 退出
        let quitItem = NSMenuItem(title: "退出 Soloist", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - UI 更新接口
    
    func updateLyricsTitle(text: String?) {
        if let button = statusItem?.button {
            button.title = text ?? ""
        }
    }
    
    func updateMenuInfo(text: String) {
        statusItem?.menu?.item(withTag: 100)?.title = text
    }
    
    // MARK: - 事件响应
    
    @objc private func toggleMenuBarLyrics(_ sender: NSMenuItem) {
        prefs.showMenuBarLyrics.toggle()
        sender.state = prefs.showMenuBarLyrics ? .on : .off
        
        if !prefs.showMenuBarLyrics {
            updateLyricsTitle(text: nil)
        }
    }
    
    @objc private func toggleFloatingWindow(_ sender: NSMenuItem) {
        prefs.showFloatingWindow.toggle()
        sender.state = prefs.showFloatingWindow ? .on : .off
        
        // 联动更新锁定按钮的可点击状态
        statusItem?.menu?.item(withTag: 101)?.isEnabled = prefs.showFloatingWindow
        
        if prefs.showFloatingWindow {
            LyricsWindowManager.shared.show()
        } else {
            LyricsWindowManager.shared.hide()
        }
    }
    
    @objc private func toggleLock(_ sender: NSMenuItem) {
        prefs.isWindowLocked.toggle()
        sender.state = prefs.isWindowLocked ? .on : .off
        
        // 通知窗口物理引擎更新穿透状态
        LyricsWindowManager.shared.updateLockState()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func unmount() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }
}
