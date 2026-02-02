//
//  Notification+Ext.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

extension Notification.Name {
    
    // MARK: - Custom Notifications
    
    /// 切换桌面歌词显示状态通知
    ///
    /// **用途**: 用于在不同模块（如 macOS 菜单栏按钮、全局快捷键监听器）与歌词控制器之间进行解耦通信。
    /// **发送者**: `MacHomeView` (菜单栏点击) 或 `AppDelegate` (快捷键触发)。
    /// **接收者**: `DesktopLyricsController` 监听此通知以执行 `toggle()` 操作。
    static let toggleDesktopLyrics = Notification.Name("toggleDesktopLyrics")
}
