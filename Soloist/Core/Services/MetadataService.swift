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
        
        do {
            let metadata = try await asset.load(.commonMetadata)
            
            for item in metadata {
                guard let key = item.commonKey else { continue }
                
                switch key {
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
        } catch {
            print("解析失败: \(url.lastPathComponent) - \(error)")
        }
        
        return Song(
            url: url,
            title: title, // 如果没读到，Song 的 init 会自动处理成文件名
            artist: artist,
            artworkData: artworkData
        )
    }
}
