//
//  PlaylistDetailView.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/4/5.
//

import SwiftUI

/// 通用歌单详情页 (支持红心列表与自定义歌单)
struct PlaylistDetailView: View {
    
    @EnvironmentObject var playerService: AudioPlayerService
    @EnvironmentObject var localLibrary: LocalLibraryService
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    
    let title: String
    let songIDs: [String]
    
    // 可选参数：用于区分是红心列表还是普通歌单，以便支持删歌等特定操作
    var isFavoriteList: Bool = false
    var playlistID: UUID? = nil
    
    // 核心水合计算属性：将 String ID 映射为真实的 Song 对象
    private var hydratedSongs: [Song] {
        // 利用 compactMap，如果本地库里找不到这个 ID，就自动过滤掉这首“死歌”
        songIDs.compactMap { id in
            localLibrary.songs.first { $0.id == id }
        }
    }
    
    var body: some View {
        List {
            if hydratedSongs.isEmpty {
                Text("列表为空")
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                // 顶部播放全部按钮
                Section {
                    Button(action: {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        // 将整个水合后的歌单灌入播放引擎，并从第一首开始播
                        if let firstSong = hydratedSongs.first {
                            playerService.play(song: firstSong, playlist: hydratedSongs)
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("播放全部")
                            Spacer()
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                    }
                }
                
                // 歌曲列表区 (利用你封装的跨平台 Shared Component)
                Section {
                    ForEach(hydratedSongs) { song in
                        let isPlaying = playerService.currentSong?.id == song.id
                        
                        // 你的高度复用组件
                        SongListRow(
                            song: song,
                            isPlaying: isPlaying,
                            onPlay: {
                                // 点击单曲时，同样要把整个列表作为上下文传给播放器
                                playerService.play(song: song, playlist: hydratedSongs)
                            },
                            onAdd: {
                                // 点击加号：这里可以后续接管“添加到另一个歌单”的逻辑
                                // 目前我们可以先让它插队播放
                                playerService.addToNext(song: song)
                            }
                        )
                        // 侧滑删除 (从当前歌单中移除)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if isFavoriteList {
                                    userPlaylistManager.toggleFavorite(songID: song.id)
                                } else if let pid = playlistID {
                                    userPlaylistManager.removeSong(song.id, fromPlaylist: pid)
                                }
                            } label: {
                                Label("移除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
