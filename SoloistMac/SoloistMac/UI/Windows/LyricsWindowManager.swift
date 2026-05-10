//
//  LyricsWindowManager.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import AppKit
import SwiftUI

class LyricsWindowManager: NSObject, NSWindowDelegate {
    static let shared = LyricsWindowManager()
    private var window: NSPanel?
    private let prefs = Preferences.shared
    
    // 鼠标监听器：Global 用于应用在后台，Local 用于应用在前台
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    
    @MainActor
    func show() {
        if window == nil {
            createWindow()
        }
        window?.orderFrontRegardless()
        updateLockState()
    }
    
    @MainActor
    func hide() {
        window?.orderOut(nil)
    }
    
    @MainActor
    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 180),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(NSWindow.Level.mainMenu.rawValue) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.delegate = self
        
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        let hostingController = NSHostingController(rootView: LyricsView())
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentViewController = hostingController
        
        let defaultWidth: CGFloat = 800
        let defaultHeight: CGFloat = 180
        
        if prefs.windowPositionX == 0 && prefs.windowPositionY == 0 {
            if let screen = NSScreen.main {
                let x = (screen.visibleFrame.width - defaultWidth) / 2
                let y = screen.visibleFrame.origin.y + (screen.visibleFrame.height * 0.12)
                panel.setFrame(NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight), display: true)
            }
        } else {
            panel.setFrame(NSRect(x: prefs.windowPositionX, y: prefs.windowPositionY, width: defaultWidth, height: defaultHeight), display: true)
        }
        
        self.window = panel
    }
    
    // MARK: - 状态切换与鼠标监听逻辑
    
    @MainActor
    func updateLockState() {
        guard let panel = window else { return }
        
        if prefs.isWindowLocked {
            panel.ignoresMouseEvents = true
            panel.isMovableByWindowBackground = false
            
            // 开启前后台监听，确保鼠标躲避逻辑生效
            if globalMouseMonitor == nil {
                globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                    self?.checkMouseDodge()
                }
            }
            if localMouseMonitor == nil {
                localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                    self?.checkMouseDodge()
                    return event
                }
            }
        } else {
            // 解锁状态：接管鼠标并允许抓取透明背景
            panel.ignoresMouseEvents = false
            panel.isMovableByWindowBackground = true
            
            if let global = globalMouseMonitor {
                NSEvent.removeMonitor(global)
                globalMouseMonitor = nil
            }
            if let local = localMouseMonitor {
                NSEvent.removeMonitor(local)
                localMouseMonitor = nil
            }
            panel.animator().alphaValue = 1.0
        }
    }
    
    @MainActor
    private func checkMouseDodge() {
        guard let panel = window, prefs.isWindowLocked else { return }
        let mouseLocation = NSEvent.mouseLocation
        
        let dodgeRect = panel.frame.insetBy(dx: -20, dy: -20)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            if dodgeRect.contains(mouseLocation) {
                panel.animator().alphaValue = 0.1
            } else {
                panel.animator().alphaValue = 1.0
            }
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let panel = window else { return }
        prefs.windowPositionX = panel.frame.origin.x
        prefs.windowPositionY = panel.frame.origin.y
    }
}
