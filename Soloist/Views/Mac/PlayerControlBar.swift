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
    
    // MARK: - Persistent Settings
    
    // 1. 桌面歌词开关 (新增：让桌面歌词也能记住开关状态)
    @AppStorage("showDesktopLyrics") private var showDesktopLyrics: Bool = false
    
    // 2. 状态栏歌词开关
    @AppStorage("showMenuBarLyrics") private var showMenuBarLyrics: Bool = false
    
    // 3. 触控栏歌词开关
    @AppStorage("showTouchBarLyrics") private var showTouchBarLyrics: Bool = false
    
    // MARK: - Local State
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    
    var body: some View {
        HStack(spacing: 20) {
            
            // MARK: - 1. 左侧：歌曲信息 (保持不变)
            HStack {
                ArtworkView(song: playerService.currentSong, size: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playerService.currentSong?.title ?? "Soloist")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(playerService.currentSong?.artist ?? "让音乐回归纯粹")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 150, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { showLyrics.toggle() }
            .help("点击展开全屏歌词")
            
            Spacer()
            
            // MARK: - 2. 中间：核心控制区 (保持不变)
            VStack(spacing: 6) {
                
                // A. 进度条 (TimelineView)
                if playerService.duration > 0 {
                    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                        HStack(spacing: 8) {
                            Text(formatTime(isDragging ? dragProgress : playerService.currentTime))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .trailing)
                            
                            Slider(
                                value: Binding(
                                    get: { isDragging ? dragProgress : playerService.currentTime },
                                    set: { isDragging = true; dragProgress = $0 }
                                ),
                                in: 0...playerService.duration,
                                onEditingChanged: { editing in
                                    isDragging = editing
                                    if !editing { playerService.seek(to: dragProgress) }
                                }
                            )
                            .controlSize(.mini)
                            .tint(.primary)
                            
                            Text(formatTime(playerService.duration))
                                .font(.system(size: 10).monospacedDigit())
                                .foregroundColor(.secondary)
                                .frame(width: 35, alignment: .leading)
                        }
                    }
                } else {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                        .padding(.horizontal, 40)
                }
                
                // B. 播放控制按钮
                HStack(spacing: 28) {
                    ControlButton(icon: "shuffle", isActive: playerService.isShuffleMode) {
                        playerService.toggleShuffle()
                    }
                    
                    Button(action: { playerService.previous() }) {
                        Image(systemName: "backward.end.fill").font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { playerService.togglePlayPause() }) {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { playerService.next() }) {
                        Image(systemName: "forward.end.fill").font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    
                    ControlButton(icon: "repeat", isActive: playerService.isLoopMode) {
                        playerService.toggleLoop()
                    }
                }
            }
            .frame(maxWidth: 420)
            
            Spacer()
            
            // MARK: - 3. 右侧：视觉输出控制组 (纯文字风格)
            HStack(spacing: 12) {
                
                Divider().frame(height: 20)
                
                // 1. 桌面歌词 -> "词"
                TextToggleButton(
                    text: "词",
                    isActive: showDesktopLyrics, // 绑定 AppStorage
                    help: "桌面悬浮歌词"
                ) {
                    showDesktopLyrics.toggle()
                    // 动作：根据新状态显示或隐藏
                    if showDesktopLyrics {
                        DesktopLyricsController.shared.show()
                    } else {
                        DesktopLyricsController.shared.hide()
                    }
                }
                .onAppear {
                    // 启动自动恢复
                    if showDesktopLyrics { DesktopLyricsController.shared.show() }
                }
                
                // 2. 状态栏歌词 -> "栏"
                TextToggleButton(
                    text: "栏",
                    isActive: showMenuBarLyrics,
                    help: "状态栏歌词"
                ) {
                    showMenuBarLyrics.toggle()
                    // 关键修复：强制通知 AppDelegate 刷新 (解决点击没反应的问题)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
                    }
                }
                
                // 3. 触控栏歌词 -> "触"
                if TouchBarManager.shared.isFeatureAvailable {
                    TextToggleButton(
                        text: "触",
                        isActive: showTouchBarLyrics,
                        help: "触控栏歌词"
                    ) {
                        showTouchBarLyrics.toggle()
                        if showTouchBarLyrics {
                            TouchBarManager.shared.present()
                        } else {
                            TouchBarManager.shared.dismiss()
                        }
                    }
                    .onAppear {
                        if showTouchBarLyrics { TouchBarManager.shared.present() }
                    }
                }
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "00:00" }
        let m = Int(time) / 60
        let s = Int(time) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Subcomponents

/// 纯文字风格的开关按钮 (保持"词"字的方块风格)
struct TextToggleButton: View {
    let text: String
    let isActive: Bool
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                // 保持原本的硬核风格：特粗字体，字号 10
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(isActive ? .accentColor : .secondary.opacity(0.6))
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        // ✨ 修复点：显式使用 Color.accentColor 和 Color.secondary
                        .stroke(isActive ? Color.accentColor : Color.secondary.opacity(0.6), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ControlButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
