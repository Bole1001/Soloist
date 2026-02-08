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
    // MARK: - State Objects
    @StateObject private var libraryService = LocalLibraryService()
    @EnvironmentObject var playerService: AudioPlayerService
    
    // 页面状态
    @State private var showLyricsPage = false
    @State private var showFileImporter = false
    @State private var currentArtworkData: Data? = nil
    
    // Tab 选中状态
    @State private var selection: String = "library"
    
    var body: some View {
        // ✨ 1. 标准 TabView 容器
        TabView(selection: $selection) {
            
            Tab("首页", systemImage: "house.fill", value: "library") {
                LocalLibraryPage()
            }
            
            Tab("播放中", systemImage: "magnifyingglass", value: "search") {
                ZStack {
                    IOSBackgroundView(artworkData: currentArtworkData)
                    ContentUnavailableView("搜索", systemImage: "magnifyingglass")
                }
            }
            
            TabSection("设置") {
                Tab("设置", systemImage: "music.note.list", value: "playlists") {
                    Text("Playlists")
                }
            }
        }
        // ✨ 2. 核心修复：使用 isEnabled 参数彻底消除“幽灵占位”
        // 只有当 isEnabled 为 true 时，系统才会分配布局空间
        .tabViewBottomAccessory(isEnabled: playerService.currentSong != nil) {
            MiniPlayerBar(showLyrics: $showLyricsPage)
                // 进场/离场动画：配合 isEnabled 变化，实现从底部平滑滑入/滑出
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        // 配合动画修饰符，确保布局回收时的过渡是丝滑的
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: playerService.currentSong?.id != nil)
        
        // ✨ 3. 动态收缩行为
        .tabBarMinimizeBehavior(.onScrollDown)
        
        // 全局全屏页 (歌词)
        .fullScreenCover(isPresented: $showLyricsPage) {
            LyricsFullView(
                playerService: playerService,
                showLyrics: $showLyricsPage,
                artworkData: currentArtworkData
            )
        }
        // 生命周期与数据加载
        .onAppear { libraryService.loadLocalDocuments() }
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtworkData = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtworkData = nil
            }
        }
        // 文件导入
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, UTType(filenameExtension: "lrc") ?? .plainText],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                libraryService.importSongs(from: urls)
            }
        }
    }
    
    // MARK: - 子视图：本地音乐库
    @ViewBuilder
    private func LocalLibraryPage() -> some View {
        ZStack {
            IOSBackgroundView(artworkData: currentArtworkData)
            NavigationStack {
                VStack(spacing: 0) {
                    if libraryService.songs.isEmpty {
                        emptyStateView
                    } else {
                        songListView
                    }
                }
                .navigationTitle("本地音乐")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { libraryService.loadLocalDocuments() }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
    }
    
    // 列表视图
    private var songListView: some View {
        List {
            ForEach(libraryService.songs) { song in
                SongListRow(
                    song: song,
                    isPlaying: playerService.currentSong?.id == song.id,
                    onPlay: { playerService.play(song: song, playlist: libraryService.songs) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(.white.opacity(0.2))
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            }
            .onDelete { indexSet in
                libraryService.deleteSongs(at: indexSet)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        // ✅ 这里的 safeAreaInset 已经移除，确保能触发收缩
    }
    
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
