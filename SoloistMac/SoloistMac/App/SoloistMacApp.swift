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
        // 这里只负责声明一个无主窗口的场景，具体启动逻辑交给 AppDelegate
        Settings {
            EmptyView()
        }
    }
}
