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
    
    // 记录悬停状态 (macOS)
    #if os(macOS)
    @State private var isHovering: Bool = false
    #endif
    
    // 判断何时显示遮罩层
    private var shouldShowOverlay: Bool {
        #if os(macOS)
        return isPlaying || isHovering
        #else
        return isPlaying
        #endif
    }
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                
                // MARK: - 1. Artwork Section
                ZStack {
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
                    
                    if shouldShowOverlay {
                        Color.black.opacity(0.4)
                            .transition(.opacity)
                        
                        #if os(macOS)
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        #else
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
            // 扩大点击区域，确保点击空白处也能触发
            .contentShape(Rectangle())
        }
        // 应用自定义样式，处理背景色和按压动画
        .buttonStyle(SongRowButtonStyle(isPlaying: isPlaying, isHovering: isHoveringForStyle))
        
        // 保持 macOS 的悬停逻辑
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        #endif
    }
    
    // 辅助计算属性：为了让 iOS 编译通过
    private var isHoveringForStyle: Bool {
        #if os(macOS)
        return isHovering
        #else
        return false
        #endif
    }
}

// MARK: - Custom Button Style
/// 专门用于处理列表行的点击态、播放态和悬停态
struct SongRowButtonStyle: ButtonStyle {
    let isPlaying: Bool
    let isHovering: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        // 1. 播放中
        if isPlaying {
            return Color.accentColor.opacity(0.1)
        }
        
        // 2. 按压 (iOS/Mac 通用)
        if isPressed {
            return Color.gray.opacity(0.2) // 按下时的深色反馈
        }
        
        // 3. 鼠标悬停
        if isHovering {
            return Color.gray.opacity(0.1)
        }
        
        // 4. 默认透明
        return Color.clear
    }
}
