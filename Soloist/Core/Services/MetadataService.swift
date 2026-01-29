//
//  MetadataService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import AVFoundation

struct MetadataService {
    
    static func parse(url: URL) async -> Song {
        let asset = AVURLAsset(url: url)
        
        var title: String?
        var artist: String?
        var artworkData: Data?
        var lyrics: String?
        
        do {
            // 加载所有元数据
            let metadata = try await asset.load(.metadata)
            
            for item in metadata {
                
                // --- A. 先处理通用键 (歌名、歌手、封面) ---
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case .commonKeyTitle:
                        title = try? await item.load(.stringValue)
                    case .commonKeyArtist:
                        artist = try? await item.load(.stringValue)
                    case .commonKeyArtwork:
                        if let data = try? await item.load(.dataValue) {
                            artworkData = data
                        } else if let value = try? await item.load(.value) as? Data {
                            artworkData = value
                        }
                    default:
                        break
                    }
                }
                
                // --- B. 单独处理歌词 (直接匹配原始字符串) ---
                // item.key 是一个对象，我们先把它强转成 String
                if let keyString = item.key as? String {
                    
                    // "USLT" = MP3 的歌词标签 (Unsynchronized Lyrics)
                    // "©lyr" = m4a/iTunes 的歌词标签
                    if keyString == "USLT" || keyString == "©lyr" {
                        lyrics = try? await item.load(.stringValue)
                    }
                }
            }
        } catch {
            print("解析失败: \(url.lastPathComponent)")
        }
        
        return Song(
            url: url,
            title: title,
            artist: artist,
            artworkData: artworkData,
            lrcURL: nil,
            embeddedLyrics: lyrics // 填入挖出来的歌词
        )
    }
}
