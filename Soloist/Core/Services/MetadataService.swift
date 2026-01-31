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
        var lyrics: String?
        
        // 1. 只加载必要的文字信息，不需要 .commonKeyArtwork
        do {
            let metadata = try await asset.load(.metadata)
            
            for item in metadata {
                if let commonKey = item.commonKey {
                    switch commonKey {
                    case .commonKeyTitle:
                        title = try? await item.load(.stringValue)
                    case .commonKeyArtist:
                        artist = try? await item.load(.stringValue)
                    // ✂️ 这里关于 Artwork 的代码全部删掉！
                    default:
                        break
                    }
                }
                
                // 歌词还要留着
                if let keyString = item.key as? String {
                    if keyString == "USLT" || keyString == "©lyr" || keyString == "SYLT" {
                        lyrics = try? await item.load(.stringValue)
                    }
                }
            }
        } catch {
            print("⚠️ 解析出错: \(url.lastPathComponent)")
        }
        
        return Song(
            url: url,
            title: title,
            artist: artist,
            // artworkData 参数已经没了，不用传
            lrcURL: nil,
            embeddedLyrics: lyrics
        )
    }
}
