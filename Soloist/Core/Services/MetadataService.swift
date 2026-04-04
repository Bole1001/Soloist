//
//  MetadataService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import AVFoundation

/// 元数据解析服务 (MetadataService)
///
/// **职责**: 负责从音频文件中提取轻量级的元数据（标题、艺术家、内嵌歌词）。
/// **层级**: Core Layer (Service)。
///
/// **设计原则**:
/// 该服务**故意不加载**封面图片 (Artwork)。
/// 因为在扫描数千首歌曲时，加载图片会导致极其严重的内存峰值和 I/O 阻塞。
/// 图片加载应推迟到 UI 显示阶段由 `ArtworkLoader` 按需处理。
struct MetadataService {
    
    /// 解析音频文件的元数据
    ///
    /// - Parameter url: 音频文件的本地 URL
    /// - Returns: 包含基础信息的 Song 对象（不含封面数据）
    static func parse(url: URL) async -> Song {
        let asset = AVURLAsset(url: url)
        
        var title: String?
        var artist: String?
        var lyrics: String?
        
        do {
            // 异步加载所有元数据项
            let metadata = try await asset.load(.metadata)
            
            for item in metadata {
                // 1. 处理通用键值 (Common Keys)
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case .commonKeyTitle:
                        title = try? await item.load(.stringValue)
                    case .commonKeyArtist:
                        artist = try? await item.load(.stringValue)
                    default:
                        break
                    }
                }
                
                // 2. 处理内嵌歌词
                if let keyString = item.key as? String {
                    // USLT: ID3v2 非同步歌词
                    // SYLT: ID3v2 同步歌词
                    // ©lyr: iTunes/M4A 歌词原子
                    if keyString == "USLT" || keyString == "©lyr" || keyString == "SYLT" {
                        lyrics = try? await item.load(.stringValue)
                    }
                }
            }
        } catch {
            print("⚠️ [MetadataService] 解析元数据失败: \(url.lastPathComponent) - \(error)")
        }
        
        // 3. 核心修复：仅提取相对路径作为稳定 ID，不再篡改真实 URL
        let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        var stableID = url.path
        
        if stableID.hasPrefix(docsPath) {
            stableID = String(stableID.dropFirst(docsPath.count))
        } else {
            // 外部挂载目录，直接使用文件名作为稳定 ID
            stableID = url.lastPathComponent
        }
        
        // 4. 返回模型
        return Song(
            id: stableID,    // 稳定的标识符
            url: url,        // 保留真实 URL
            title: title ?? url.deletingPathExtension().lastPathComponent,
            artist: artist ?? "Unknown Artist",
            lrcURL: nil,
            embeddedLyrics: lyrics
        )
    }
}
