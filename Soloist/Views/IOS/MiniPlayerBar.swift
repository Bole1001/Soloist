//
//  MiniPlayerBar.swift
//  Soloist
//
//  Created by Bole on 2026/2/7.
//

import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    
    // 核心：从环境值获取当前 Bar 的形态 (系统自动注入)
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    
    @Namespace private var liquidNamespace
    
    var body: some View {
        ZStack {
            // ===========================================
            // Layer 1 (底层): 负责“液态玻璃”效果
            // 包含两种形态的背景形状，通过 placement 切换
            // ===========================================
            GlassEffectContainer {
                if placement == .expanded {
                    // 悬浮态背景 (大胶囊)
                    Capsule(style: .continuous)
                        .glassEffect(.regular.interactive()) // 玻璃材质 + 交互反馈
                        .frame(height: 70)
                        .glassEffectID("background", in: liquidNamespace)
                } else {
                    // 行内态背景 (融入 TabBar 的扁平条)
                    // 当 List 向下滚动时，系统会自动切换到这个状态
                    Rectangle()
                        .glassEffect(.regular) // 较弱的模糊，适应行内样式
                        .frame(height: 50)
                        .glassEffectID("background", in: liquidNamespace)
                }
            }
            
            // ===========================================
            // Layer 2 (顶层): 负责“清晰内容”
            // 内容浮在玻璃层之上，绝对清晰
            // ===========================================
            Group {
                if placement == .expanded {
                    ExpandedContent()
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else {
                    CompactContent()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // 全局点击手势
        .onTapGesture { showLyrics = true }
        // 绑定默认动画，让收缩/展开的物理形变(Morphing)更顺滑
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: placement)
    }
    
    // MARK: - 清晰的内容视图 (悬浮态)
    
    @ViewBuilder
    private func ExpandedContent() -> some View {
        HStack(spacing: 16) {
            // 1. 封面
            if let song = playerService.currentSong {
                // 🔴 关键修正：移除了 .id(song.id)，保持视图存活
                // 配合 ArtworkView 内部的缓存逻辑，解决切歌闪烁问题
                ArtworkView(song: song, size: 48)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                    .matchedGeometryEffect(id: "artwork", in: liquidNamespace)
            }
            
            // 2. 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(playerService.currentSong?.title ?? "Not Playing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(playerService.currentSong?.artist ?? "Soloist")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 3. 按钮
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        playerService.togglePlayPause()
                    }
                }) {
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                Button(action: { playerService.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24) // 内容的边距
    }
    
    // MARK: - 清晰的内容视图 (行内态)
    
    @ViewBuilder
    private func CompactContent() -> some View {
        HStack(spacing: 12) {
            // 微型封面
            if let song = playerService.currentSong {
                ArtworkView(song: song, size: 30)
                    .clipShape(Circle())
                    .matchedGeometryEffect(id: "artwork", in: liquidNamespace)
            }
            
            // 仅显示歌名 (极简模式)
            Text(playerService.currentSong?.title ?? "Soloist")
                .font(.subheadline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 仅显示播放/暂停
            Button(action: { playerService.togglePlayPause() }) {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        // 支持左右轻扫切歌 (iOS 26 盲操规范)
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.width < -30 {
                    playerService.next()
                } else if value.translation.width > 30 {
                    playerService.previous()
                }
            }
        )
    }
}
