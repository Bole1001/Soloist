//
//  QueuePage.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import SwiftUI

struct QueuePage: View {
    @EnvironmentObject var playerService: AudioPlayerService
    // 接收封面数据用于背景模糊
    let artworkData: Data?
    
    // 自动滚动到当前播放歌曲
    @State private var didScrollToCurrent = false
    
    var body: some View {
        ZStack {
            // 1. 背景层
            IOSBackgroundView(artworkData: artworkData)
            
            NavigationStack {
                ScrollViewReader { proxy in
                    List {
                        // MARK: - 播放队列
                        Section {
                            if playerService.queue.isEmpty {
                                emptyQueueView
                            } else {
                                // 必须直接遍历 queue 数组才能支持 onMove
                                ForEach(playerService.queue) { song in
                                    let isCurrent = playerService.currentSong?.id == song.id
                                    
                                    SongListRow(
                                        song: song,
                                        isPlaying: isCurrent,
                                        onPlay: {
                                            // 点击队列里的歌，直接播放那一首
                                            playerService.play(song: song, playlist: playerService.queue)
                                        }
                                    )
                                    .id(song.id) // 绑定 ID 以便自动滚动
                                    // 给正在播放的行加个特殊的背景
                                    .listRowBackground(
                                        isCurrent ? Color.white.opacity(0.15) : Color.clear
                                    )
                                    .listRowSeparatorTint(.white.opacity(0.2))
                                }
                                .onDelete(perform: playerService.removeSongs)
                                .onMove(perform: playerService.moveSongs)
                            }
                        } header: {
                            headerView
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .navigationTitle("待播清单")
                    .toolbar {
                        // 系统的编辑按钮 (点击进入排序/删除模式)
                        EditButton()
                    }
                    // 进页面时自动滚到正在播放的那首歌
                    .onAppear {
                        if let currentId = playerService.currentSong?.id, !didScrollToCurrent {
                            // 稍微延迟一下等待 List 渲染
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    proxy.scrollTo(currentId, anchor: .center)
                                }
                                didScrollToCurrent = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var headerView: some View {
        HStack {
            Text("播放队列")
            Spacer()
            if !playerService.queue.isEmpty {
                Text("\(playerService.queue.count) 首歌曲")
                    .font(.caption)
                    .textCase(nil) // 取消全大写
            }
        }
        .foregroundStyle(.secondary)
    }
    
    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("队列为空")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}
