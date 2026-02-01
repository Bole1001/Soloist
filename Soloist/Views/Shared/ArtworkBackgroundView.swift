//
//  ArtworkBackgroundView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// 🔧 适配层
#if os(macOS)
import AppKit
typealias BgImage = NSImage
#else
import UIKit
typealias BgImage = UIImage
#endif

struct ArtworkBackgroundView: View {
    let song: Song?
    
    // 内部状态，独立管理加载
    @State private var artworkData: Data? = nil
    
    var body: some View {
        Group {
            if let data = artworkData, let image = BgImage(data: data) {
                GeometryReader { geo in
                    #if os(macOS)
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .drawingGroup() // 🚀 关键优化：使用 Metal 渲染模糊
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                    #else
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .drawingGroup()
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                    #endif
                }
                .ignoresSafeArea()
            } else {
                // 默认渐变背景
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
        // 监听歌曲变化，自动重新加载
        .task(id: song?.id) {
            if let currentSong = song {
                artworkData = await ArtworkLoader.loadArtwork(for: currentSong)
            } else {
                artworkData = nil
            }
        }
        // 增加一个动画过渡，让切歌背景变化更平滑
        .animation(.linear(duration: 0.5), value: artworkData)
    }
}
