//
//  SoloistMacApp.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/9.
//

import SwiftUI
import AppKit

@main
struct SoloistMacApp: App {
    // 强制挂载传统的 AppDelegate 以接管底层系统事件
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 纯状态栏应用不需要主窗口，使用 Settings 占位防止默认弹窗
        Settings {
            EmptyView()
        }
    }
}
