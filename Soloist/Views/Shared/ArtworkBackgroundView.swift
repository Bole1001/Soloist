//
//  ArtworkBackgroundView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// MARK: - 跨平台适配层
// 统一不同平台的图片类类型别名，方便后续逻辑复用
import UIKit
typealias BgImage = UIImage

/// 动态封面背景视图 (ArtworkBackgroundView)
///
/// **职责**: 显示当前歌曲的封面作为全屏模糊背景。
/// **特性**:
/// 1. 跨平台兼容 (自动适配 macOS/iOS)。
/// 2. 异步加载图片数据，避免阻塞主线程。
/// 3. 使用 Metal (`drawingGroup`) 加速模糊渲染，防止 UI 卡顿。
/// 4. 无封面时提供默认的优雅渐变兜底。
struct ArtworkBackgroundView: View {
    
    // MARK: - Dependencies
    /// 当前歌曲对象 (用于获取封面 ID)
    let song: Song?
    
    // MARK: - Local State
    /// 内部持有的图片数据，独立管理加载生命周期
    @State private var artworkData: Data? = nil
    
    var body: some View {
        Group {
            // 尝试将 Data 转换为当前平台的图片对象 (NSImage 或 UIImage)
            if let data = artworkData, let image = BgImage(data: data) {
                GeometryReader { geo in
                    // 根据平台特性构建 Image 视图
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .drawingGroup()
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                }
                .ignoresSafeArea() // 铺满全屏，覆盖状态栏和安全区域
            } else {
                // MARK: - Empty State
                // 无封面时的默认暗色渐变背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(white: 0.2), Color.black]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
            }
        }
        // MARK: - Lifecycle & Data Loading
        // 监听歌曲变化 (根据 ID)，自动触发异步加载任务
        // 使用 .task 的好处是：当视图销毁或 ID 变化时，未完成的任务会自动取消
        .task(id: song?.id) {
            if let currentSong = song {
                artworkData = await ArtworkLoader.loadArtwork(for: currentSong)
            } else {
                artworkData = nil
            }
        }
        // 添加平滑过渡动画，避免背景切换时过于生硬
        .animation(.linear(duration: 0.5), value: artworkData)
    }
}
