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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 核心任务：通知状态栏管理器开始工作
        MenuBarManager.shared.setup()
    }
    
    // MARK: - App Lifecycle
    
    // 关闭最后一个窗口后，不退出 App (因为我们有状态栏图标)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // 重新打开主窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 让 MenuBarManager 去处理打开窗口的逻辑，保持统一
            MenuBarManager.shared.openMainWindow()
        }
        return true
    }
}
#endif
