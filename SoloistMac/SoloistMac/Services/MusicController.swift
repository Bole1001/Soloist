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
    enum AccessError: Error, CustomStringConvertible {
        case appNotRunning
        case applicationUnavailable
        case bridgeUnavailable
        case playerPositionUnavailable
        case commandUnavailable(String)
        
        var description: String {
            switch self {
            case .appNotRunning:
                return "Apple Music 未运行"
            case .applicationUnavailable:
                return "无法创建 Apple Music 桥接"
            case .bridgeUnavailable:
                return "Apple Music 桥接不可用"
            case .playerPositionUnavailable:
                return "无法读取播放位置"
            case .commandUnavailable(let command):
                return "Apple Music 不支持 \(command) 控制"
            }
        }
    }
    
    private static var musicApp: SBApplication? = {
        return SBApplication(bundleIdentifier: "com.apple.Music")
    }()
    
    static func readCurrentPosition() -> Result<Double, AccessError> {
        guard let app = musicApp else {
            return .failure(.applicationUnavailable)
        }
        
        guard app.isRunning else {
            return .failure(.appNotRunning)
        }
        
        // 将 SBApplication 安全转型为我们定义的协议类型
        guard let bridgedApp = app as? AppleMusicApplication else {
            return .failure(.bridgeUnavailable)
        }
        
        guard let position = bridgedApp.playerPosition else {
            return .failure(.playerPositionUnavailable)
        }
        
        return .success(position)
    }
    
    static func getCurrentPosition() -> Double? {
        if case let .success(position) = readCurrentPosition() {
            return position
        }
        return nil
    }

    static func togglePlayPause() -> Result<Void, AccessError> {
        performPlaybackCommand(selectorName: "playpause", displayName: "播放/暂停")
    }

    static func nextTrack() -> Result<Void, AccessError> {
        performPlaybackCommand(selectorName: "nextTrack", displayName: "下一首")
    }

    static func previousTrack() -> Result<Void, AccessError> {
        performPlaybackCommand(selectorName: "previousTrack", displayName: "上一首")
    }

    private static func performPlaybackCommand(selectorName: String, displayName: String) -> Result<Void, AccessError> {
        guard let app = musicApp else {
            return .failure(.applicationUnavailable)
        }

        guard app.isRunning else {
            return .failure(.appNotRunning)
        }

        let selector = NSSelectorFromString(selectorName)
        guard app.responds(to: selector) else {
            return .failure(.commandUnavailable(displayName))
        }

        _ = app.perform(selector)
        return .success(())
    }
}
