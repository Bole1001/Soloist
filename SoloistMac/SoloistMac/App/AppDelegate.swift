//
//  AppDelegate.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import Foundation
import AppKit

// AppDelegate 拦截器
class AppDelegate: NSObject, NSApplicationDelegate {
    let phantomGuard = PhantomGuard.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 删除 NSApp.setActivationPolicy(.accessory)
        phantomGuard.startSystem()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        phantomGuard.handleReopen()
        return true
    }
}
