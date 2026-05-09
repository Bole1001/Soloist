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
    
    var isFavoriteList: Bool = false
    var playlistID: UUID? = nil
    
    // 直接使用 O(1) 的哈希字典进行极速水合
    private var hydratedSongs: [Song] {
        songIDs.compactMap { id in
            localLibrary.songDictionary[id]
        }
    }
    
    var body: some View {
        Group {
            if hydratedSongs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("列表为空")
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    // MARK: - 1. 顶部操作面板 (Apple Music 规范)
                    Section {
                        HStack(spacing: 16) {
                            // 播放全部大按钮
                            Button(action: {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                if let firstSong = hydratedSongs.first {
                                    // 强制关闭随机模式，按列表顺序播放
                                    playerService.isShuffleMode = false
                                    playerService.play(song: firstSong, playlist: hydratedSongs)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("播放")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                            // 必须阻断 List 点击劫持
                            .buttonStyle(.plain)
                            
                            // 随机播放大按钮
                            Button(action: {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                if let firstSong = hydratedSongs.randomElement() {
                                    // 强制开启随机模式
                                    playerService.isShuffleMode = true
                                    playerService.play(song: firstSong, playlist: hydratedSongs)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "shuffle")
                                    Text("随机播放")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                            // 必须阻断 List 点击劫持
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden) // 隐藏头部的分割线
                    
                    // MARK: - 2. 歌曲列表区
                    Section {
                        ForEach(hydratedSongs) { song in
                            let isPlaying = playerService.currentSong?.id == song.id
                            
                            SongListRow(
                                song: song,
                                isPlaying: isPlaying,
                                onPlay: {
                                    playerService.play(song: song, playlist: hydratedSongs)
                                },
                                onAdd: {
                                    playerService.addToNext(song: song)
                                }
                            )
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    #if os(iOS)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    #endif
                                    playerService.addToNext(song: song)
                                } label: {
                                    Label("下一首播放", systemImage: "text.insert")
                                }
                                .tint(.accentColor) // 使用 App 主题色（通常是蓝色或紫色）
                            }
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
                        .onMove { source, destination in
                            if isFavoriteList {
                                userPlaylistManager.moveFavorites(from: source, to: destination)
                            } else if let pid = playlistID {
                                userPlaylistManager.moveSongs(inPlaylist: pid, from: source, to: destination)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
