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
    private var menuBarLyricsItem: NSMenuItem?
    private var floatingWindowItem: NSMenuItem?
    private var lockItem: NSMenuItem?

    var onToggleMenuBarLyrics: (() -> Void)?
    var onToggleFloatingWindow: (() -> Void)?
    var onToggleLock: (() -> Void)?
    var onQuit: (() -> Void)?
    
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
        menuBarLyricItem.state = .off
        menu.addItem(menuBarLyricItem)
        self.menuBarLyricsItem = menuBarLyricItem
        
        // 3. 悬浮窗开关 (接入记忆)
        let floatingWindowItem = NSMenuItem(title: "桌面悬浮窗", action: #selector(toggleFloatingWindow), keyEquivalent: "w")
        floatingWindowItem.target = self
        floatingWindowItem.state = .off
        menu.addItem(floatingWindowItem)
        self.floatingWindowItem = floatingWindowItem
        
        // 4. 新增：锁定开关 (Tag 101)
        let lockItem = NSMenuItem(title: "锁定歌词位置", action: #selector(toggleLock), keyEquivalent: "l")
        lockItem.target = self
        lockItem.state = .off
        lockItem.isEnabled = false
        lockItem.tag = 101
        menu.addItem(lockItem)
        self.lockItem = lockItem
        
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
    
    @objc private func toggleMenuBarLyrics(_: NSMenuItem) {
        onToggleMenuBarLyrics?()
    }
    
    @objc private func toggleFloatingWindow(_: NSMenuItem) {
        onToggleFloatingWindow?()
    }
    
    @objc private func toggleLock(_: NSMenuItem) {
        onToggleLock?()
    }
    
    @objc private func quitApp() {
        onQuit?() ?? NSApplication.shared.terminate(nil)
    }
    
    func unmount() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
        menuBarLyricsItem = nil
        floatingWindowItem = nil
        lockItem = nil
    }

    func syncState(showMenuBarLyrics: Bool, showFloatingWindow: Bool, isWindowLocked: Bool) {
        menuBarLyricsItem?.state = showMenuBarLyrics ? .on : .off
        floatingWindowItem?.state = showFloatingWindow ? .on : .off
        lockItem?.state = isWindowLocked ? .on : .off
        lockItem?.isEnabled = showFloatingWindow
        if !showMenuBarLyrics {
            updateLyricsTitle(text: nil)
        }
    }

    func setPlaybackInfo(text: String) {
        updateMenuInfo(text: text)
    }

    func clearLyricsTitle() {
        updateLyricsTitle(text: nil)
    }
}
