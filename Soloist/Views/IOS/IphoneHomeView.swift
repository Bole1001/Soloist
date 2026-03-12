//
//  IphoneHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/2/6.
//

import SwiftUI
import UniformTypeIdentifiers

/// iOS 端主页视图 (IphoneHomeView)
struct IphoneHomeView: View {
    // MARK: - Search Logic
    // 搜索框的输入内容
    @State private var searchText = ""
    
    // 根据搜索内容过滤后的歌曲列表
    private var filteredSongs: [Song] {
        if searchText.isEmpty {
            return libraryService.songs
        } else {
            return libraryService.songs.filter { song in
                song.title.localizedCaseInsensitiveContains(searchText) ||
                song.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 控制删除确认弹窗的状态
    @State private var showDeleteConfirmation = false
    // 临时记录准备删除的歌曲实体
    @State private var pendingDeleteSongs: [Song] = []
    
    // MARK: - State Objects
    @StateObject private var libraryService = LocalLibraryService()
    @EnvironmentObject var playerService: AudioPlayerService
    
    // 页面状态
    @State private var showLyricsPage = false
    @State private var showFileImporter = false
    @State private var currentArtworkData: Data? = nil
    
    // 控制播放列表弹窗的状态
    @State private var showQueueSheet = false
    
    // Tab 选中状态
    @State private var selection: String = "library"
    
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
            
            // Tab 3: 视效
            Tab("视效", systemImage: "sparkles.tv", value: "visualizer") {
                VisualizerPage(artworkData: currentArtworkData)
            }
            
            // Tab 4: 设置
            Tab("设置", systemImage: "gearshape.fill", value: "settings") {
                SettingsPage(libraryService: libraryService, artworkData: currentArtworkData)
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
        .onAppear { libraryService.loadLocalDocuments() }
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
                    if libraryService.songs.isEmpty {
                        emptyStateView
                    } else {
                        buildSongList(songs: libraryService.songs)
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
                    onPlay: { playerService.play(song: song, playlist: libraryService.songs) },
                    onAdd: { playerService.addToNext(song: song) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(.white.opacity(0.2))
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .onDelete { indexSet in
                // 不直接删，先把要删的歌找出来存进临时数组
                pendingDeleteSongs = indexSet.map { songs[$0] }
                // 触发确认弹窗
                showDeleteConfirmation = true
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        
        // 挂载系统原生的底部确认弹窗
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("删除歌曲", role: .destructive) {
                // 用户点击了红色的确认删除
                for song in pendingDeleteSongs {
                    // 去全库里找这首歌的真实索引
                    if let realIndex = libraryService.songs.firstIndex(where: { $0.id == song.id }) {
                        libraryService.deleteSongs(at: IndexSet(integer: realIndex))
                    }
                }
                // 删完清空临时记录
                pendingDeleteSongs.removeAll()
            }
            Button("取消", role: .cancel) {
                // 用户反悔了，清空记录即可
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
            Button("立即导入") { showFileImporter = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
