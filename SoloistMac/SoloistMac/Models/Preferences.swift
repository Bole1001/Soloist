//
//  Preferences.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import Foundation
import SwiftUI

@Observable
class Preferences {
    static let shared = Preferences()
    
    // 使用 UserDefaults 进行数据持久化
    private let defaults = UserDefaults.standard
    
    // MARK: - 存储键名
    private enum Keys {
        static let showFloatingWindow = "showFloatingWindow"
        static let showMenuBarLyrics = "showMenuBarLyrics"
        static let windowPositionX = "windowPositionX"
        static let windowPositionY = "windowPositionY"
        static let windowScale = "windowScale"
    }
    
    // MARK: - 状态变量
    
    // 菜单开关
    var showFloatingWindow: Bool {
        didSet { defaults.set(showFloatingWindow, forKey: Keys.showFloatingWindow) }
    }
    var showMenuBarLyrics: Bool {
        didSet { defaults.set(showMenuBarLyrics, forKey: Keys.showMenuBarLyrics) }
    }
    
    // 窗口坐标与大小
    var windowPositionX: Double {
        didSet { defaults.set(windowPositionX, forKey: Keys.windowPositionX) }
    }
    var windowPositionY: Double {
        didSet { defaults.set(windowPositionY, forKey: Keys.windowPositionY) }
    }
    var windowScale: Double {
        didSet { defaults.set(windowScale, forKey: Keys.windowScale) }
    }
    
    // 编辑模式（无需保存，每次重启默认锁定，防止误触）
    var isWindowLocked: Bool = true
    
    private init() {
        // 初始化时读取本地保存的值，如果没有保存过，就给定一个默认值
        // 注册默认值，防止第一次打开时读不到数据
        defaults.register(defaults: [
            Keys.showFloatingWindow: false,
            Keys.showMenuBarLyrics: true,
            Keys.windowScale: 1.0
            // 坐标不设默认值，留给窗口自己判断屏幕中心
        ])
        
        self.showFloatingWindow = defaults.bool(forKey: Keys.showFloatingWindow)
        self.showMenuBarLyrics = defaults.bool(forKey: Keys.showMenuBarLyrics)
        self.windowPositionX = defaults.double(forKey: Keys.windowPositionX)
        self.windowPositionY = defaults.double(forKey: Keys.windowPositionY)
        self.windowScale = defaults.double(forKey: Keys.windowScale)
    }
}
