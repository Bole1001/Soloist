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
    
    // ✨ 新增：用于存储异步加载的封面图片数据
    @State private var currentArtwork: Data? = nil
    
    var body: some View {
        HStack(spacing: 20) {
            
            // --- 1. 左侧：封面与歌名 ---
            HStack {
                // ✨ 修改点：不再读 song.artworkData，而是读本地 State 里的 currentArtwork
                if let data = currentArtwork,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(6)
                } else {
                    // 占位图
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
            .contentShape(Rectangle())
            .onTapGesture {
                showLyrics.toggle()
            }
            .help("点击查看完整歌词")
            
            Spacer()
            
            // --- 2. 中间：歌词 + 控制按钮 ---
            VStack(spacing: 6) {
                HStack(spacing: 24) {
                    // 1. 随机播放
                    Button(action: { playerService.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15))
                            .foregroundColor(playerService.isShuffleMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
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
                    
                    // 5. 循环播放
                    Button(action: { playerService.toggleLoop() }) {
                        Image(systemName: "repeat")
                            .font(.system(size: 15))
                            .foregroundColor(playerService.isLoopMode ? .blue : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // 6. 桌面歌词开关
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
        // ✨✨✨ 核心逻辑：监听歌曲 ID 变化，异步加载图片 ✨✨✨
        // .task(id:) 是 SwiftUI 专门处理异步刷新的神器，比 .onChange 更好用
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                // 有歌 -> 去硬盘挖图片 (不卡顿)
                currentArtwork = await ArtworkLoader.loadArtwork(for: song)
            } else {
                // 没歌 -> 清空图片
                currentArtwork = nil
            }
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
