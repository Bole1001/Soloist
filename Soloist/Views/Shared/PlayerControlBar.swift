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
    
    var body: some View {
        HStack(spacing: 20) {
            
            // --- 1. 左侧：封面与歌名 (点击可打开歌词页) ---
            HStack {
                if let data = playerService.currentSong?.artworkData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "music.note").foregroundColor(.gray))
                }
                
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
            .contentShape(Rectangle()) // 确保点击区域覆盖整个左侧
            .onTapGesture {
                showLyrics.toggle()
            }
            .help("点击查看完整歌词")
            
            Spacer()
            
            // --- 2. 中间：歌词 + 控制按钮 ---
            VStack(spacing: 6) {
                // 歌词显示区域
                if !playerService.currentLyric.isEmpty {
                    Text(playerService.currentLyric)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.blue) // 高亮颜色
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .id(playerService.currentLyric)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                } else {
                    Text(" ")
                        .font(.system(size: 14))
                }
                
                // 控制按钮组
                HStack(spacing: 24) {
                    // 1. 随机播放
                    Button(action: { playerService.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15))
                            .foregroundColor(playerService.isShuffleMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("随机播放")
                    
                    // 2. 上一首
                    Button(action: { playerService.previous() }) {
                        Image(systemName: "backward.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                    
                    // 3. 播放/暂停
                    Button(action: { playerService.togglePlayPause() }) {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                    }
                    .buttonStyle(.plain)
                    
                    // 4. 下一首
                    Button(action: { playerService.next() }) {
                        Image(systemName: "forward.fill").font(.title3)
                    }
                    .buttonStyle(.plain)
                    
                    // ✨ 5. 新增：循环播放
                    Button(action: { playerService.toggleLoop() }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 15))
                            // 激活变蓝 (默认是激活的)，关闭变灰
                            .foregroundColor(playerService.isLoopMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("循环播放")
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
        .background(.ultraThinMaterial) // 毛玻璃背景
        .overlay(Divider(), alignment: .top)
    }
    
    // 辅助函数：格式化时间
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
