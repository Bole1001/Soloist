//
//  MusicController.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import Foundation
import ScriptingBridge

// 1. 定义 Apple Music 的部分底层接口协议
// 这种做法不需要到处生成庞大的 .h 头文件，只映射我们需要用到的属性
@objc protocol AppleMusicApplication {
    @objc optional var playerPosition: Double { get }
}

// 2. 将 SBApplication 桥接到该协议
extension SBApplication: AppleMusicApplication {}

struct MusicController {
    
    private static var musicApp: SBApplication? = {
        return SBApplication(bundleIdentifier: "com.apple.Music")
    }()
    
    static func getCurrentPosition() -> Double? {
        guard let app = musicApp, app.isRunning else { return nil }
        
        // 将 SBApplication 安全转型为我们定义的协议类型
        if let bridgedApp = app as? AppleMusicApplication,
           let position = bridgedApp.playerPosition {
            return position
        }
        
        return nil
    }
}
