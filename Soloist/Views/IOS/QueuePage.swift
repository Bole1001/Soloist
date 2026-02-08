//
//  QueuePage.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import SwiftUI

/// 专门用于 MiniPlayer 弹出的简易播放列表视图
struct QueuePage: View {
    @EnvironmentObject var playerService: AudioPlayerService
    
    var body: some View {
        NavigationStack {
            List {
                // 1. 顶部控制区 (类似网易云的“播放全部/循环模式”)
                Section {
                    HStack {
                        // 循环模式切换按钮
                        Button(action: { playerService.toggleLoop() }) {
                            HStack {
                                Image(systemName: playerService.isLoopMode ? "repeat.1" : "repeat")
                                Text(playerService.isLoopMode ? "单曲循环" : "列表循环")
                            }
                            .font(.subheadline)
                            .foregroundStyle(playerService.isLoopMode ? .blue : .primary)                        }
                        
                        Spacer()
                        
                        // 随机播放
                        Button(action: { playerService.toggleShuffle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "shuffle")
                                Text(playerService.isShuffleMode ? "随机播放" : "顺序播放")
                            }
                            .font(.subheadline)
                            // 激活时变色，状态更清晰
                            .foregroundStyle(playerService.isShuffleMode ? .blue : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                
                // 2. 歌曲列表 (复用逻辑)
                Section {
                    if playerService.queue.isEmpty {
                        Text("队列为空")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(playerService.queue) { song in
                            let isCurrent = playerService.currentSong?.id == song.id
                            
                            HStack(spacing: 12) {
                                // 正在播放的动态图标
                                if isCurrent {
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundStyle(.blue)
                                        .font(.caption)
                                } else {
                                    // 序号或空位
                                    Text("\(playerService.queue.firstIndex(where: {$0.id == song.id})! + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(song.title)
                                        .foregroundStyle(isCurrent ? .blue : .primary)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playerService.play(song: song, playlist: playerService.queue)
                            }
                            .listRowBackground(isCurrent ? Color.primary.opacity(0.05) : Color.clear)
                        }
                        // 支持侧滑删除
                        .onDelete(perform: playerService.removeSongs)
                        // 支持拖拽排序 (必须在 EditMode 下或长按，Sheet 里通常长按即可)
                        .onMove(perform: playerService.moveSongs)
                    }
                }
            }
            .listStyle(.plain)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("当前播放")
                        .font(.headline)
                }
            }
        }
    }
}
