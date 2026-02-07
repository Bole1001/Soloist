//
//  IphoneHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/2/6.
//

import SwiftUI
import UniformTypeIdentifiers

/// iOS 端主页视图 (IphoneHomeView)
///
/// **结构**: 采用 ZStack 分层结构 (背景 + 内容 + 播放条 + 全屏页)。
/// **核心功能**:
/// 1. **主页**: 歌曲列表、文件导入入口。
/// 2. **视觉**: 复刻 Mac 端的沉浸式动态背景。
/// 3. **交互**: 底部迷你播放条，点击展开全屏歌词。
struct IphoneHomeView: View {
    
    // MARK: - State Objects
    @StateObject private var libraryService = LocalLibraryService()
    @EnvironmentObject var playerService: AudioPlayerService
    
    // MARK: - Local State
    @State private var showLyricsPage = false
    @State private var showFileImporter = false
    @State private var currentArtworkData: Data? = nil
    
    var body: some View {
        ZStack {
            // 1. 背景层
            IOSBackgroundView(artworkData: currentArtworkData)
            
            // 2. 主内容层
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
                    // 左侧：手动刷新 (应对 iTunes 传文件后不显示的极少数情况)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { libraryService.loadLocalDocuments() }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    // 右侧：导入按钮
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            
            // 3. 底部播放条
            if playerService.currentSong != nil {
                VStack {
                    Spacer()
                    MiniPlayerBar(showLyrics: $showLyricsPage)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(1)
            }
            
            // 4. 全屏歌词页
            if showLyricsPage {
                LyricsFullView(
                    playerService: playerService,
                    showLyrics: $showLyricsPage,
                    artworkData: currentArtworkData
                )
                .transition(.move(edge: .bottom))
                .zIndex(2)
            }
        }
        // 动画与生命周期
        .animation(.easeInOut(duration: 0.3), value: showLyricsPage)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: playerService.currentSong)
        
        // 视图可见时自动扫描沙盒 (应对 iTunes 文件共享)
        .onAppear {
            libraryService.loadLocalDocuments()
        }
        
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtworkData = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtworkData = nil
            }
        }
        
        // 允许导入 音频 和 纯文本(歌词)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, UTType(filenameExtension: "lrc") ?? .plainText], // 允许 mp3 和 lrc/txt
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                libraryService.importSongs(from: urls)
            }
        }
    }
    
    // MARK: - Subviews Extraction
    
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
            // 增加左滑删除功能
            .onDelete { indexSet in
                libraryService.deleteSongs(at: indexSet)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .safeAreaInset(edge: .bottom) {
            if playerService.currentSong != nil {
                Color.clear.frame(height: 80)
            }
        }
    }
}
