//
//  SongListRow.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// MARK: - Platform Adaptation
#if os(macOS)
import AppKit
typealias SongRowImage = NSImage
#else
import UIKit
typealias SongRowImage = UIImage
#endif

struct SongListRow: View {
    // MARK: - Parameters
    let song: Song
    let isPlaying: Bool
    let onPlay: () -> Void
    
    // MARK: - Local State
    @State private var rowArtwork: Data? = nil
    
    // ✨ 1. 状态隔离：只有 macOS 需要记录悬停状态
    #if os(macOS)
    @State private var isHovering: Bool = false
    #endif
    
    // ✨ 2. 逻辑计算属性：判断何时显示遮罩层
    private var shouldShowOverlay: Bool {
        #if os(macOS)
        return isPlaying || isHovering
        #else
        return isPlaying // iOS 上只有“正在播放”时才显示遮罩
        #endif
    }
    
    var body: some View {
        HStack(spacing: 14) {
            
            // MARK: - 1. Artwork Section
            ZStack {
                // A. 封面图
                if let data = rowArtwork, let image = SongRowImage(data: data) {
                    #if os(macOS)
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    #else
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                }
                
                // B. 遮罩层 (根据平台逻辑显示)
                if shouldShowOverlay {
                    Color.black.opacity(0.4)
                        .transition(.opacity)
                    
                    // 图标逻辑区分
                    #if os(macOS)
                    // Mac: 播放显示喇叭，未播放但悬停显示播放键
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    #else
                    // iOS: 只显示喇叭 (因为 iOS 没有悬停状态，不需要 play.fill)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    #endif
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            .task(id: song.id) {
                if rowArtwork == nil {
                    rowArtwork = await ArtworkLoader.loadArtwork(for: song)
                }
            }
            
            // MARK: - 2. Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isPlaying ? .blue : .primary)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .contentShape(Rectangle()) // 扩大点击区域
        
        // MARK: - Interaction & Styling
        // 背景高亮逻辑也做区分
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundFill)
        )
        // ✨ 3. 修饰符隔离：只在 Mac 上添加悬停监听
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        #endif
        .onTapGesture {
            onPlay()
        }
    }
    
    // ✨ 4. 辅助属性：背景填充色逻辑
    private var backgroundFill: Color {
        if isPlaying {
            return Color.accentColor.opacity(0.1)
        }
        
        #if os(macOS)
        if isHovering {
            return Color.gray.opacity(0.1)
        }
        #endif
        
        return Color.clear
    }
}
