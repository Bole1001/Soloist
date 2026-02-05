//
//  ArtworkLoader.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation
import AVFoundation

/// 封面加载器 (ArtworkLoader)
///
/// 这是一个无状态的工具结构体，专门负责处理繁重的音频元数据读取任务。
///
/// **设计哲学**:
/// 1. **平台无关性**: 只返回 `Data?` 而不是 `UIImage` 或 `NSImage`。这使得该逻辑可以在 Mac、iOS 和 WatchOS 之间 100% 复用。
/// 2. **异步优先**: 强制使用 `async`，确保文件 I/O 操作永远不会阻塞主线程（UI线程）。
/// 3. **按需加载**: 只有当 UI 真正显示封面时（在 `.task` 中）才会调用此方法，极大节省了内存。
struct ArtworkLoader {
    
    // MARK: - Public API
    
    /// 异步从音频文件中提取封面图片数据
    ///
    /// 该方法会打开指定 URL 的音频文件，解析 ID3 标签或其他元数据容器，
    /// 查找类型为 `.commonKeyArtwork` 的数据项。
    ///
    /// - Parameter song: 需要加载封面的歌曲模型（包含 url）。
    /// - Returns: 图片的原始二进制数据 (`Data`)。如果文件没有封面或读取失败，返回 `nil`。
    static func loadArtwork(for song: Song) async -> Data? {
        // 1. 创建资源对象
        // AVURLAsset 初始化非常快，它只是指向文件，还没开始读取数据。
        let asset = AVURLAsset(url: song.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        
        do {
            // 2. 异步加载元数据 (耗时操作)
            // 这里使用了 Swift 5.5+ 的新并发 API，替代了旧的 loadValuesAsynchronously
            let metadata = try await asset.load(.metadata)
            
            // 3. 遍历元数据查找封面
            for item in metadata {
                // AVMetadataKey.commonKeyArtwork 是通用的封面键值，
                // 它可以兼容 ID3v2 (MP3) 和 iTunes Atom (M4A) 等多种格式。
                if item.commonKey == .commonKeyArtwork {
                    
                    // 4. 尝试提取数据 (双重保险策略)
                    
                    // 策略 A: 尝试使用新版类型安全 API (.dataValue)
                    if let data = try? await item.load(.dataValue) {
                        return data
                    }
                    // 策略 B: 回退旧版 API (.value)，并尝试转为 Data
                    // 某些旧编码格式的音频文件可能只能通过这种方式获取
                    else if let value = try? await item.load(.value) as? Data {
                        return value
                    }
                }
            }
        } catch {
            // 生产环境中，通常不需要把这个错误抛给 UI，返回 nil 显示占位图即可。
            // 这里的 print 仅用于开发调试。
            print("❌ [ArtworkLoader] 读取封面失败: \(song.title) - \(error)")
        }
        
        return nil
    }
}
