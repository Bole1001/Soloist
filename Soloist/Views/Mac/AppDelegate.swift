//
//  AppDelegate.swift
//  Soloist
//
//  Created by Bole on 2026/2/2.
//

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
    
    // 拦截系统底层 Handoff 唤醒
        func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
            
            if userActivity.activityType == "com.soloist.handoff.playback" {
                print("🚀 [AppDelegate] 拦截到接力包，正在通过总线强行空投至视图层...")
                // 发送系统通知，把 userActivity 塞在 object 里带过去
                NotificationCenter.default.post(name: .handoffDidArrive, object: userActivity)
                return true
            }
            return false
        }
}

extension Notification.Name {
    /// 跨端接力数据到达通知
    static let handoffDidArrive = Notification.Name("SoloistHandoffDidArrive")
}
