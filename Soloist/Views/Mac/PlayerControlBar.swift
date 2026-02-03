//
//  PlayerControlBar.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

/// 底部播放控制条 (PlayerControlBar)
struct PlayerControlBar: View {
    
    // MARK: - Dependencies
    @ObservedObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    
    // MARK: - Local State for Slider
    /// 是否正在拖拽进度条 (用于解决“拖拽时被定时器重置”的冲突问题)
    @State private var isDragging: Bool = false
    /// 拖拽过程中的临时进度值
    @State private var dragProgress: Double = 0.0
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 20) {
            
            // MARK: - 1. 左侧：歌曲信息
            HStack {
                ArtworkView(song: playerService.currentSong, size: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerService.currentSong?.title ?? "未播放")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(playerService.currentSong?.artist ?? "-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 150, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { showLyrics.toggle() }
            .help("点击查看完整歌词")
            
            Spacer()
            
            // MARK: - 2. 中间：控制按钮 + 进度条
            VStack(spacing: 8) {
                
                // A. 进度条区域
                if playerService.duration > 0 {
                    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                        HStack(spacing: 8) {
                            // 当前时间
                            Text(formatTime(isDragging ? dragProgress : playerService.currentTime))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            // 进度滑块
                            Slider(
                                value: Binding(
                                    get: {
                                        // 主动读取 Service 里的普通变量
                                        isDragging ? dragProgress : playerService.currentTime
                                    },
                                    set: { newValue in
                                        isDragging = true
                                        dragProgress = newValue
                                    }
                                ),
                                in: 0...playerService.duration,
                                onEditingChanged: { editing in
                                    isDragging = editing
                                    if !editing {
                                        playerService.seek(to: dragProgress)
                                    }
                                }
                            )
                            .controlSize(.small)
                            
                            // 总时长
                            Text(formatTime(playerService.duration))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .leading)
                        }
                    }
                } else {
                    // 未播放/无时长时的占位
                    ProgressView(value: 0)
                        .progressViewStyle(.linear)
                        .frame(height: 6)
                        .opacity(0.5)
                }
                
                // B. 按钮区域
                HStack(spacing: 24) {
                    Button(action: { playerService.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14))
                            .foregroundColor(playerService.isShuffleMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    PlaybackControls(playerService: playerService, size: 32)
                    
                    Button(action: { playerService.toggleLoop() }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 14))
                            .foregroundColor(playerService.isLoopMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // 桌面歌词按钮
                    Button(action: {
                        DesktopLyricsController.shared.toggle()
                    }) {
                        Text("词")
                            .font(.system(size: 10, weight: .heavy)) // 稍微调小字号以适应正方形
                            // ✨ 关键修改 1：根据状态变色 (同时改变文字和边框颜色)
                            .foregroundColor(DesktopLyricsController.shared.isShow ? .blue : .secondary.opacity(0.6))
                            // ✨ 关键修改 2：强制指定正方形尺寸 (替代 padding)
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    // 边框颜色也要跟着变
                                    .stroke(DesktopLyricsController.shared.isShow ? .blue : .secondary.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("桌面悬浮歌词")
                }
            }
            .frame(maxWidth: 400) // 限制中间区域宽度
            
            Spacer()
            
            // MARK: - 3. 右侧：音量控制 (可选)
            // 原来的时间进度移到中间了，右侧空出来可以放音量，或者留白
            // 这里暂时留白，保持对称
            Color.clear
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helper
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
