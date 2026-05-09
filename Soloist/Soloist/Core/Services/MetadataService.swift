//
//  MetadataService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import AVFoundation

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
        
        // 3. 提取与清洗安全数据
        let safeTitle = title ?? url.deletingPathExtension().lastPathComponent
        let safeArtist = artist ?? "Unknown Artist"
        
        // 4. 绝对确定性 ID 生成 (Intrinsic ID)
        // 摒弃所有外部文件路径层级的干扰，使用底层元数据生成唯一防碰撞 ID
        let stableID = "\(safeArtist)-\(safeTitle)"
        
        // 5. 返回模型
        return Song(
            id: stableID,
            url: url,
            title: safeTitle,
            artist: safeArtist,
            lrcURL: nil,
            embeddedLyrics: lyrics
        )
    }
}
