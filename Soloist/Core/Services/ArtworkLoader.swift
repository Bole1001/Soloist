//
//  ArtworkLoader.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation
import AVFoundation
import SwiftUI // 如果你需要返回 Image 或 NSImage

struct ArtworkLoader {
    
    // 给定一首歌，去硬盘里把封面挖出来
    static func loadArtwork(for song: Song) async -> Data? {
        let asset = AVURLAsset(url: song.url)
        do {
            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if item.commonKey == .commonKeyArtwork {
                    if let data = try? await item.load(.dataValue) {
                        return data
                    } else if let value = try? await item.load(.value) as? Data {
                        return value
                    }
                }
            }
        } catch {
            print("读取封面失败: \(error)")
        }
        return nil
    }
}
