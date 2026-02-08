//
//  ArtworkView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// MARK: - Platform Adaptation
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// 全局缓存单例
private class ArtworkCache {
    static let shared = NSCache<NSString, NSData>()
}

struct ArtworkView: View {
    
    // MARK: - Dependencies
    let song: Song?
    let size: CGFloat
    
    // MARK: - Local State
    @State private var currentArtwork: Data? = nil
    
    // MARK: - ✨ 关键修复：自定义初始化方法
    init(song: Song?, size: CGFloat) {
        self.song = song
        self.size = size
        
        // 核心逻辑：在 View 刚出生时，直接同步去缓存里拿图
        // 如果拿到图，直接把 @State 初始化为这张图，而不是 nil
        // 这样即使 View 被反复销毁重建，也不会出现“先显示灰图”的情况
        if let currentSong = song {
            let cacheKey = currentSong.id.uuidString as NSString
            if let cachedData = ArtworkCache.shared.object(forKey: cacheKey) {
                // 使用 _currentArtwork 对 State 进行底层初始化
                _currentArtwork = State(initialValue: cachedData as Data)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 1. 背景占位图 (始终存在，垫在底下)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                        .font(.system(size: size * 0.5))
                )
            
            // 2. 封面图片层
            if let data = currentArtwork, let image = PlatformImage(data: data) {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                #endif
            }
        }
        // 强制约束尺寸
        .frame(width: size, height: size)
        .cornerRadius(6)
        .clipped()
        
        // 绑定动画：让图片变化时淡入淡出 (解决切歌时的生硬感)
        .animation(.easeInOut(duration: 0.3), value: currentArtwork)
        
        // MARK: - Data Loading
        // 这里的任务主要负责：1. 没缓存时的异步加载 2. 数据更新
        .task(id: song?.id) {
            guard let currentSong = song else {
                currentArtwork = nil
                return
            }
            
            let cacheKey = currentSong.id.uuidString as NSString
            
            // 1. 再次检查缓存 (为了双重保险)
            if let cachedData = ArtworkCache.shared.object(forKey: cacheKey) {
                if currentArtwork == nil {
                    currentArtwork = cachedData as Data
                }
                return
            }
            
            // 2. 异步加载
            // 注意：加载期间不要设为 nil，保留上一首歌的图 (如果有的话)
            let loadedData = await ArtworkLoader.loadArtwork(for: currentSong)
            
            // 3. 写入缓存并更新 UI
            if let validData = loadedData {
                ArtworkCache.shared.setObject(validData as NSData, forKey: cacheKey)
            }
            
            // 确保切歌 ID 没变才更新 UI
            if currentSong.id == song?.id {
                withAnimation {
                    currentArtwork = loadedData
                }
            }
        }
    }
}
