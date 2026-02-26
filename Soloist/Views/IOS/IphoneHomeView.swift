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
    
    // 控制播放列表弹窗的状态
    @State private var showQueueSheet = false
    
    // Tab 选中状态
    @State private var selection: String = "library"
    
    var body: some View {
        // 标准 TabView 容器
        TabView(selection: $selection) {
            // Tab 1: 首页 (保持不变，还是调用下面的 LocalLibraryPage)
            Tab("资料库", systemImage: "music.note.house.fill", value: "library") {
                LocalLibraryPage()
            }
            
            // Tab 2: 视效
            Tab("视效", systemImage: "sparkles.tv", value: "visualizer") {
                VisualizerPage(artworkData: currentArtworkData)
            }
            
            // Tab 3: 设置 (调用新文件，并把 libraryService 传进去)
            Tab("设置", systemImage: "gearshape.fill", value: "settings") {
                SettingsPage(libraryService: libraryService, artworkData: currentArtworkData)
            }
        }
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
        // 配合动画修饰符，确保布局回收时的过渡是丝滑的
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: playerService.currentSong?.id != nil)
        
        // 动态收缩行为
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
                    onPlay: { playerService.play(song: song, playlist: libraryService.songs) },
                    onAdd: {playerService.addToNext(song: song)}
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
