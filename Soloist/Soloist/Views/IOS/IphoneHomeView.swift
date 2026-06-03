//
//  IphoneHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/2/6.
//

import SwiftUI

/// iOS 端主页视图 (IphoneHomeView)
struct IphoneHomeView: View {
    // MARK: - Search Logic
    // 搜索框的输入内容
    @State private var searchText = ""
    
    // 根据搜索内容过滤后的歌曲列表
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return localLibrary.songs
        } else {
            return localLibrary.songs.filter { song in
                song.title.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 控制删除确认弹窗的状态
    @State private var showDeleteConfirmation = false
    // 临时记录准备删除的歌曲实体
    @State private var pendingDeleteSongs: [Song] = []
    
    // MARK: - Environment Objects
    @EnvironmentObject var localLibrary: LocalLibraryService
    @EnvironmentObject var playerService: AudioPlayerService
    
    // 页面状态
    @State private var showLyricsPage = false
    @State private var currentArtworkData: Data? = nil
    
    // 控制播放列表弹窗的状态
    @State private var showQueueSheet = false
    
    // Tab 选中状态
    @State private var selection: String = "library"
    
    // 仅允许首次进入时做一次启动扫描，避免每次回到主页都全量刷新
    @State private var didAttemptInitialLibraryLoad = false
    
    var body: some View {
        TabView(selection: $selection) {
            
            // Tab 1: 资料库
            Tab("资料库", systemImage: "music.note.house.fill", value: "library") {
                LocalLibraryPage()
            }
            
            // Tab 2: 搜索
            Tab("搜索", systemImage: "magnifyingglass", value: "search", role: .search) {
                NavigationStack {
                    ZStack {
                        // 背景色（系统默认）
                        Color(UIColor.systemBackground).ignoresSafeArea()
                        
                        Group {
                            // 搜索页的 3 种状态
                            if searchText.isEmpty {
                                // 状态 A：还没开始搜索
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.tertiary)
                                    Text("搜索您的音乐库")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                            } else if filteredSongs.isEmpty {
                                // 状态 B：搜了，但没找到
                                Text("找不到与 \"\(searchText)\" 相关的结果")
                                    .foregroundStyle(.secondary)
                            } else {
                                // 状态 C：显示搜索结果
                                buildSongList(songs: filteredSongs)
                            }
                        }
                    }
                    .navigationTitle("搜索")
                    .searchable(text: $searchText, prompt: "搜索歌曲或歌手")
                }
            }
            
            // Tab 3: 歌单
            Tab("歌单", systemImage: "play.square.stack", value: "playlists") {
                IphonePlaylistsView()
            }
            
            // Tab 4: 设置
            Tab("设置", systemImage: "gearshape.fill", value: "settings") {
                SettingsPage(artworkData: currentArtworkData)
            }
        }
        
        // 底部播放条辅助插件
        .tabViewBottomAccessory(isEnabled: playerService.currentSong != nil) {
            MiniPlayerBar(
                showLyrics: $showLyricsPage,
                showQueueSheet: $showQueueSheet
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .sheet(isPresented: $showQueueSheet) {
            QueuePage()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: playerService.currentSong?.id != nil)
        
        // 动态收缩行为：向下滚动时自动最小化液态 Tab 栏
        .tabBarMinimizeBehavior(playerService.currentSong != nil ? .onScrollDown : .automatic)
        
        // 全屏盖层 (歌词)
        .fullScreenCover(isPresented: $showLyricsPage) {
            LyricsFullView(
                playerService: playerService,
                showLyrics: $showLyricsPage,
                artworkData: currentArtworkData
            )
        }
        // 生命周期
        .onAppear {
            guard !didAttemptInitialLibraryLoad else { return }
            didAttemptInitialLibraryLoad = true
            if localLibrary.songs.isEmpty {
                _ = localLibrary.loadLocalDocuments()
            }
        }
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtworkData = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtworkData = nil
            }
        }
    }
    
    // MARK: - 子视图：本地音乐库
    @ViewBuilder
    private func LocalLibraryPage() -> some View {
        ZStack {
            IOSBackgroundView(artworkData: currentArtworkData)
            NavigationStack {
                Group {
                    if localLibrary.songs.isEmpty {
                        emptyStateView
                    } else {
                        buildSongList(songs: localLibrary.songs)
                    }
                }
                .navigationTitle("本地音乐")
            }
        }
    }
    
    // MARK: - 共享组件：列表视图
    private func buildSongList(songs: [Song]) -> some View {
        List {
            ForEach(songs) { song in
                SongListRow(
                    song: song,
                    isPlaying: playerService.currentSong?.id == song.id,
                    onPlay: { playerService.play(song: song, playlist: localLibrary.songs) },
                    onAdd: { playerService.addToNext(song: song) }
                )
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(.white.opacity(0.2))
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                
                // 左滑：插队播放
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        playerService.addToNext(song: song)
                    } label: {
                        Label("下一首播放", systemImage: "text.insert")
                    }
                    .tint(.accentColor)
                }
                
                // 右滑：删除
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        pendingDeleteSongs = [song]
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        
        // 挂载系统原生的底部确认弹窗
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("删除歌曲", role: .destructive) {
                for song in pendingDeleteSongs {
                    if let realIndex = localLibrary.songs.firstIndex(where: { $0.id == song.id }) {
                        localLibrary.deleteSongs(at: IndexSet(integer: realIndex))
                    }
                }
                pendingDeleteSongs.removeAll()
            }
            Button("取消", role: .cancel) {
                pendingDeleteSongs.removeAll()
            }
        } message: {
            Text("这首歌曲将从本地库中永久移除，确定吗？")
        }
    }
    
    // MARK: - 共享组件：空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("暂无本地音乐").font(.headline)
            Button("前往设置导入") { selection = "settings" }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
