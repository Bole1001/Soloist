//
//  ArtworkView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// MARK: - Platform Adaptation
// 定义通用图片类型别名，自动适配 AppKit (macOS) 和 UIKit (iOS)
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// 封面视图 (ArtworkView)
///
/// **职责**: 显示歌曲的专辑封面。
/// **特性**:
/// 1. 自动处理跨平台图片渲染 (macOS/iOS)。
/// 2. 支持异步加载数据。
/// 3. 提供统一的方形圆角样式和默认占位图。
struct ArtworkView: View {
    
    // MARK: - Dependencies
    let song: Song?
    let size: CGFloat
    
    // MARK: - Local State
    /// 存储异步加载的原始图片数据
    @State private var currentArtwork: Data? = nil
    
    var body: some View {
        Group {
            // 状态 1: 图片数据加载成功，且能转换为当前平台的图片对象
            if let data = currentArtwork, let image = PlatformImage(data: data) {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                // 状态 2: 加载中或无封面，显示默认占位图
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            // 图标大小随视图尺寸动态调整 (50% 比例)
                            .font(.system(size: size * 0.5))
                    )
            }
        }
        // 强制约束为正方形尺寸
        .frame(width: size, height: size)
        .cornerRadius(6)
        .clipped() // 裁剪超出圆角部分的内容
        
        // MARK: - Data Loading
        // 监听歌曲 ID 变化，触发异步加载任务
        // 任务会自动随视图生命周期管理 (视图销毁时自动取消)
        .task(id: song?.id) {
            if let currentSong = song {
                currentArtwork = await ArtworkLoader.loadArtwork(for: currentSong)
            } else {
                currentArtwork = nil
            }
        }
    }
}
