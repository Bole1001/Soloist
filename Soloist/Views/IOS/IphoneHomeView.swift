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
    // iOS 端独立的库管理服务
    @StateObject private var libraryService = LocalLibraryService()
    // 全局播放服务
    @EnvironmentObject var playerService: AudioPlayerService
    
    // MARK: - Local State
    /// 控制全屏歌词页的显示/隐藏
    @State private var showLyricsPage = false
    /// 控制文件导入器的显示
    @State private var showFileImporter = false
    
    // 将封面数据提升为 View 的 State (用于背景模糊)
    @State private var currentArtworkData: Data? = nil
    
    var body: some View {
        ZStack {
            
            // MARK: - Layer 1: 背景层 (沉浸式)
            HomeBackgroundView(artworkData: currentArtworkData)
                .ignoresSafeArea()
            
            // MARK: - Layer 2: 主内容 (导航与列表)
            NavigationStack {
                VStack(spacing: 0) {
                    if libraryService.songs.isEmpty {
                        // 空状态
                        VStack(spacing: 20) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("暂无本地音乐")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("点击右上角 + 号导入音频文件")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Button("立即导入") {
                                showFileImporter = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // 歌曲列表
                        List {
                            ForEach(libraryService.songs) { song in
                                SongListRow(
                                    song: song,
                                    isPlaying: playerService.currentSong?.id == song.id,
                                    onPlay: {
                                        playerService.play(song: song, playlist: libraryService.songs)
                                    }
                                )
                                .listRowBackground(Color.clear) // 透明背景，为了透出底部的模糊层
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden) // 关键：去除 List 默认背景
                        // 底部留白，防止列表被播放条挡住
                        .safeAreaInset(edge: .bottom) {
                            if playerService.currentSong != nil {
                                Color.clear.frame(height: 80)
                            }
                        }
                    }
                }
                .navigationTitle("本地音乐")
                .toolbar {
                    // 左侧：刷新
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            libraryService.refreshLibrary()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    // 右侧：添加
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showFileImporter = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            
            // MARK: - Layer 3: 底部播放条 (Overlay)
            if playerService.currentSong != nil {
                VStack {
                    Spacer()
                    MiniPlayerBar(showLyrics: $showLyricsPage)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(1) // 确保在 List 之上
            }
            
            // MARK: - Layer 4: 全屏歌词页 (Top Overlay)
            
        }
        // 动画控制
        .animation(.easeInOut(duration: 0.3), value: showLyricsPage)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: playerService.currentSong)
        
        // 生命周期：加载数据
        .onAppear {
            libraryService.loadLocalDocuments()
        }
        // 监听歌曲变化，异步加载封面 (用于背景)
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtworkData = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtworkData = nil
            }
        }
        // 文件导入逻辑
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                libraryService.importSongs(from: urls)
            case .failure(let error):
                print("导入失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Subviews (iOS Specific)

/// 动态背景视图 (iOS 适配版)
struct HomeBackgroundView: View {
    let artworkData: Data?
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if let data = artworkData,
                   let uiImage = UIImage(data: data) {
                    // 方案 A: 有封面 -> Metal 加速模糊
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .drawingGroup()
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.3)) // 稍微压暗，保证列表文字可读性
                } else {
                    // 方案 B: 无封面 -> 静态渐变 (适配 iOS 系统背景色)
                    ZStack {
                        Color(uiColor: .systemBackground)
                        
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 300, height: 300)
                            .blur(radius: 80)
                            .offset(x: -100, y: -150)
                        
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 250, height: 250)
                            .blur(radius: 60)
                            .offset(x: 100, y: 100)
                    }
                }
            }
        }
    }
}

/// 迷你播放条 (iOS 专用)
/// 类似于 Mac 端的 PlayerControlBar，但布局更紧凑
struct MiniPlayerBar: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. 封面
            ArtworkView(song: playerService.currentSong, size: 48)
                .shadow(radius: 4)
            
            // 2. 信息区 (点击展开歌词)
            VStack(alignment: .leading, spacing: 2) {
                Text(playerService.currentSong?.title ?? "Soloist")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(playerService.currentSong?.artist ?? "未播放")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle()) // 扩大点击区域
            .onTapGesture {
                showLyrics = true
            }
            
            // 3. 控制区
            HStack(spacing: 16) {
                Button(action: { playerService.togglePlayPause() }) {
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Button(action: { playerService.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial) // 毛玻璃效果
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}
