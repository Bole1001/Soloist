//
//  IphonePlaylistsView.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/4/5.
//

import SwiftUI

/// iOS 端歌单与收藏主页
struct IphonePlaylistsView: View {
    
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    @EnvironmentObject var localLibrary: LocalLibraryService
    
    // 控制新建歌单的弹窗状态
    @State private var showingNewPlaylistAlert = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. 顶部 Hero 区：我喜欢的音乐
                Section {
                    NavigationLink(destination: PlaylistDetailView(
                        title: "我喜欢的音乐",
                        songIDs: Array(userPlaylistManager.favoriteSongIDs),
                        isFavoriteList: true
                    )) {
                        HStack(spacing: 16) {
                            // 渐变红心封面
                            ZStack {
                                LinearGradient(colors: [.red.opacity(0.8), .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                            .shadow(color: .red.opacity(0.3), radius: 5, y: 3)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("我喜欢的音乐")
                                    .font(.headline)
                                Text("\(userPlaylistManager.favoriteSongIDs.count) 首歌")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.clear) // 沉浸式透明背景
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                
                // MARK: - 2. 操作区：新建歌单
                Section {
                    Button(action: {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        newPlaylistName = ""
                        showingNewPlaylistAlert = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            Text("新建歌单")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // MARK: - 3. 自建歌单列表
                Section(header: Text("我的歌单")) {
                    if userPlaylistManager.customPlaylists.isEmpty {
                        Text("暂无自建歌单")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(userPlaylistManager.customPlaylists) { playlist in
                            NavigationLink(destination: PlaylistDetailView(
                                title: playlist.name,
                                songIDs: playlist.songIDs,
                                playlistID: playlist.id
                            )) {
                                HStack(spacing: 16) {
                                    // 默认歌单封面占位
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 48, height: 48)
                                        .overlay(Image(systemName: "music.note.list").foregroundColor(.secondary))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(playlist.name)
                                            .font(.body)
                                        Text("\(playlist.songIDs.count) 首歌")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        // 支持侧滑删除歌单
                        .onDelete { offsets in
                            for index in offsets {
                                let playlist = userPlaylistManager.customPlaylists[index]
                                userPlaylistManager.deletePlaylist(id: playlist.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("资料库")
            // 新建歌单的系统弹窗
            .alert("新建歌单", isPresented: $showingNewPlaylistAlert) {
                TextField("歌单名称", text: $newPlaylistName)
                Button("取消", role: .cancel) { }
                Button("保存") {
                    userPlaylistManager.createPlaylist(name: newPlaylistName)
                }
                .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
