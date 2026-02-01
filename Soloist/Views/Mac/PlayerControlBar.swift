//
//  PlayerControlBar.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

struct PlayerControlBar: View {
    @ObservedObject var playerService: AudioPlayerService
    
    // 接收父视图传来的开关变量
    @Binding var showLyrics: Bool
    
    // ❌ 删除了：@State private var currentArtwork
    // ✅ 原因：这个状态现在由 ArtworkView 内部自己管理，不需要外部操心
    
    var body: some View {
        HStack(spacing: 20) {
            
            // --- 1. 左侧：封面与歌名 ---
            HStack {
                // ✨ 复用 Shared 组件：封面
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
            .onTapGesture {
                showLyrics.toggle()
            }
            .help("点击查看完整歌词")
            
            Spacer()
            
            // --- 2. 中间：歌词 + 控制按钮 ---
            VStack(spacing: 6) {
                HStack(spacing: 24) {
                    // 1. 随机播放 (非核心，保留在此)
                    Button(action: { playerService.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15))
                            .foregroundColor(playerService.isShuffleMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // ✨ 复用 Shared 组件：核心控制 (上/停/下)
                    // 这里的 size: 38 会自动按比例调整三个按钮的大小
                    PlaybackControls(playerService: playerService, size: 38)
                    
                    // 3. 循环播放 (非核心，保留在此)
                    Button(action: { playerService.toggleLoop() }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 15))
                            .foregroundColor(playerService.isLoopMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // 4. 桌面歌词 (Mac 独有，必须保留在此)
                    Button(action: {
                        DesktopLyricsController.shared.toggle()
                    }) {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("桌面悬浮歌词")
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            // --- 3. 右侧：时间进度 ---
            VStack(alignment: .trailing) {
                Text(formatTime(playerService.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .frame(width: 150, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // ❌ 删除了：.task(id:)
        // ✅ 原因：ArtworkView 内部已经有了 .task，这里再写就是重复加载
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
