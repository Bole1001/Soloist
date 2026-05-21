//
//  QueuePage.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import SwiftUI

/// 专门用于 MiniPlayer 弹出的播放队列与逻辑管理视图
struct QueuePage: View {
    // MARK: - Dependencies
    @EnvironmentObject var playerService: AudioPlayerService
    
    @EnvironmentObject var queueManager: PlaylistManager
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. 播放模式控制区
                Section {
                    HStack {
                        // 循环模式切换
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            queueManager.isLoopMode.toggle()
                        } label: {
                            Label(queueManager.isLoopMode ? "列表循环" : "顺序播放",
                                  systemImage: queueManager.isLoopMode ? "repeat" : "play")
                                .font(.subheadline.bold())
                                .foregroundStyle(queueManager.isLoopMode ? .blue : .primary)
                                .contentTransition(.symbolEffect(.replace)) // 丝滑切换动画
                        }
                        
                        Spacer()
                        
                        // 随机播放切换
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            withAnimation(.spring()) {
                                queueManager.isShuffleMode.toggle()
                                // 切换随机模式后，立刻重洗队列
                                queueManager.reshuffle(keepCurrentAtTop: playerService.currentSong)
                            }
                        } label: {
                            Label(queueManager.isShuffleMode ? "随机播放" : "顺序播放",
                                  systemImage: "shuffle")
                                .font(.subheadline.bold())
                                .foregroundStyle(queueManager.isShuffleMode ? .blue : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
                
                // MARK: - 2. 动态队列列表
                Section {
                    // 确定当前展示哪个列表
                    let currentDisplayList = queueManager.isShuffleMode ? queueManager.shuffledPlaylist : queueManager.originalPlaylist
                    
                    if currentDisplayList.isEmpty {
                        Text("当前队列无歌曲")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        // 使用 enumerated() 规避 $O(n)$ 查找索引，提升性能
                        ForEach(Array(currentDisplayList.enumerated()), id: \.element.id) { index, song in
                            let isCurrent = playerService.currentSong?.id == song.id
                            
                            HStack(spacing: 12) {
                                // 状态指示器
                                if isCurrent {
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: 16, weight: isCurrent ? .bold : .regular))
                                        .foregroundStyle(isCurrent ? .blue : .primary)
                                        .lineLimit(1)
                                    
                                    Text(song.artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                // 在队列里直接点红心
                                Button {
                                    userPlaylistManager.toggleFavorite(songID: song.id)
                                } label: {
                                    Image(systemName: userPlaylistManager.isFavorite(songID: song.id) ? "heart.fill" : "heart")
                                        .font(.caption)
                                        .foregroundStyle(userPlaylistManager.isFavorite(songID: song.id) ? .red : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // 切换歌曲，并告知播放器目前的队列上下文
                                playerService.play(song: song)
                            }
                            .listRowBackground(isCurrent ? Color.blue.opacity(0.08) : Color.clear)
                        }
                        .onDelete { offsets in
                            if queueManager.isShuffleMode {
                                queueManager.updateShuffledList(remove(from: queueManager.shuffledPlaylist, at: offsets))
                            } else {
                                queueManager.updateOriginalList(remove(from: queueManager.originalPlaylist, at: offsets))
                            }
                        }
                        .onMove(perform: playerService.moveSongs)
                    }
                } header: {
                    Text("待播清单")
                        .font(.caption.bold())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // 辅助函数：处理 IndexSet 删除
    private func remove(from list: [Song], at offsets: IndexSet) -> [Song] {
        var newList = list
        newList.remove(atOffsets: offsets)
        return newList
    }
}
