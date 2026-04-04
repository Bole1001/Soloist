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
    
    @Binding var showQueueSheet: Bool
    
    var body: some View {
        ZStack {
            GlassEffectContainer {
                if placement == .expanded {
                    // 悬浮态背景 (大胶囊)
                    Capsule(style: .continuous)
                        .glassEffect(.regular.interactive())
                        .frame(height: 70)
                        .glassEffectID("background", in: liquidNamespace)
                } else {
                    Rectangle()
                        .glassEffect(.regular)
                        .frame(height: 50)
                        .glassEffectID("background", in: liquidNamespace)
                }
            }
            
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: placement)
    }
    
    // MARK: - 清晰的内容视图 (悬浮态)
    
    @ViewBuilder
    private func ExpandedContent() -> some View {
        HStack(spacing: 16) {
            // 1. 封面
            if let song = playerService.currentSong {
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
            HStack(spacing: 4) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playerService.togglePlayPause()
                }) {
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showQueueSheet = true
                }) {
                    Image(systemName: "music.note.list")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
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
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                playerService.togglePlayPause()
            }) {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 30, height: 44) // 扩大纵向热区
                    .contentTransition(.symbolEffect(.replace)) // 补充丝滑过渡动画
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
}
