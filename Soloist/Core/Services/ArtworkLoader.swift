//
//  ArtworkLoader.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation
import AVFoundation
import ImageIO
import CryptoKit
import UIKit

/// 封面加载器 (ArtworkLoader)
struct ArtworkLoader {
    
    // MARK: - Cache Architecture
    
    private static let memoryCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 300 // 增加索引上限
        cache.totalCostLimit = 1024 * 1024 * 30 // 压缩后单图极小，30MB 足矣
        return cache
    }()
    
    private static let diskCacheURL: URL = {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("ArtworkCache_V2")
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        }
        return cacheDir
    }()
    
    // MARK: - Public API
    
    static func loadArtwork(for song: Song) async -> Data? {
        let rawKey = "\(song.artist)-\(song.title)"
        let cacheKey = SHA256.hash(data: Data(rawKey.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let nsKey = NSString(string: cacheKey)
        
        // 1. L1 内存拦截
        if let cachedData = memoryCache.object(forKey: nsKey) {
            return Data(referencing: cachedData)
        }
        
        // 2. L2 磁盘拦截
        let fileURL = diskCacheURL.appendingPathComponent(cacheKey)
        if let diskData = try? Data(contentsOf: fileURL) {
            memoryCache.setObject(NSData(data: diskData), forKey: nsKey)
            return diskData
        }
        
        // 3. 原始解析
        let asset = AVURLAsset(url: song.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])
        
        do {
            let metadata = try await asset.load(.metadata)
            for item in metadata where item.commonKey == .commonKeyArtwork {
                
                var rawData: Data? = try? await item.load(.dataValue)
                if rawData == nil {
                    rawData = try? await item.load(.value) as? Data
                }
                
                if let validData = rawData {
                    // ✨ 优化 2：下采样压缩
                    // 将原始大图直接转为 120x120 的高质量缩略图（体积约 10-20KB）
                    guard let compressedData = createThumbnail(from: validData, size: 120) else { return nil }
                    
                    memoryCache.setObject(NSData(data: compressedData), forKey: nsKey)
                    
                    Task.detached(priority: .background) {
                        try? compressedData.write(to: fileURL)
                    }
                    
                    return compressedData
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    // MARK: - High Performance Downsampling
    
    /// 使用 ImageIO 进行高性能下采样，避免解码大位图
    private static func createThumbnail(from data: Data, size: CGFloat) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size
        ]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        // 将压缩后的图片转回 Data
        let uiImage = UIImage(cgImage: image)
        return uiImage.jpegData(compressionQuality: 0.8)
    }
}
