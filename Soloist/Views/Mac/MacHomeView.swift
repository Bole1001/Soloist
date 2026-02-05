//
//  MacHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

/// macOS 端主页视图 (MacHomeView)
///
/// **结构**: 采用 NavigationSplitView (Sidebar + Detail) 结构。
/// **核心功能**:
/// 1. **侧边栏**: 音乐库导航、文件夹导入、歌曲数量统计。
/// 2. **详情页**: 歌曲列表、沉浸式动态背景、底部播放条。
/// 3. **全屏歌词**: 通过 ZStack 叠加在最上层的独立视图。
struct MacHomeView: View {
    
    // MARK: - State Objects
    @StateObject private var libraryService = LocalLibraryService()
    @StateObject private var playerService = AudioPlayerService.shared
    
    // MARK: - Local State
    /// 控制全屏歌词页的显示/隐藏
    @State private var showLyricsPage = false
    /// 侧边栏选中项 ID
    @State private var selection: String? = "all"
    
    // 将封面数据提升为 View 的 State
    @State private var currentArtworkData: Data? = nil
    
    var body: some View {
        ZStack {
            
            // MARK: - Layer 1: 主导航界面
            NavigationSplitView {
                // === 左侧：侧边栏 ===
                ZStack {
                    // 1. 背景层：通透的毛玻璃
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    // 2. 列表层
                    List(selection: $selection) {
                        // 唯一的导航入口：当前文件夹
                        NavigationLink(value: "all") {
                            Label {
                                if let folder = libraryService.accessingURL {
                                    Text(folder.lastPathComponent) // 显示文件夹名
                                        .font(.system(size: 14, weight: .medium))
                                } else {
                                    Text("未选择文件夹") // 没选的时候显示这个
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                // 使用文件夹图标，更有“本地文件”的感觉
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 6) //稍微增加一点高度，显得不那么挤
                        }
                        .listRowSeparator(.hidden) // 去掉分割线，更干净
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden) // 去掉默认灰底
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220)
                }
                // 3. 底部工具栏 (保持功能性)
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 16) {
                        // 添加文件夹
                        Button(action: { openFolderPicker() }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary.opacity(0.8))
                        .help("更换/添加音乐文件夹")
                        
                        Spacer()
                        
                        // 简单的计数
                        if !libraryService.songs.isEmpty {
                            Text("\(libraryService.songs.count) 首歌")
                                .font(.system(size: 11, design: .monospaced)) // 用等宽字体显得更有极客感
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // 刷新
                        Button(action: { libraryService.refreshLibrary() }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary.opacity(0.8))
                        .help("刷新当前文件夹")
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 20)
                    .background(.ultraThinMaterial) // 底部也是毛玻璃
                    .overlay(Divider().opacity(0.2), alignment: .top) // 极淡的分割线
                }
                
            } detail: {
                // === 右侧：详情内容区域 (保持原样) ===
                ZStack {
                    // 背景
                    HomeBackgroundView(artworkData: currentArtworkData)
                    
                    // 内容
                    VStack(spacing: 0) {
                        if libraryService.songs.isEmpty {
                            // 空状态
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.house.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.tertiary)
                                Text("暂无本地音乐").font(.title2).fontWeight(.medium)
                                Text("请点击左下角 + 号选择文件夹")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.inset)
                            .scrollContentBackground(.hidden)
                            .safeAreaInset(edge: .bottom) {
                                if playerService.currentSong != nil {
                                    Color.clear.frame(height: 80)
                                }
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if playerService.currentSong != nil {
                        PlayerControlBar(
                            playerService: playerService,
                            showLyrics: $showLyricsPage
                        )
                        .frame(height: 80)
                        .background(.ultraThinMaterial)
                        .overlay(Divider().opacity(0.5), alignment: .top)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            
            // MARK: - Layer 2: 全屏歌词页 (Overlay)
            // 覆盖在所有内容之上
            if showLyricsPage {
                LyricsFullView(
                    playerService: playerService,
                    showLyrics: $showLyricsPage,
                    artworkData: currentArtworkData
                )
                .transition(.move(edge: .bottom))
                .zIndex(1) // 确保层级最高
            }
        }
        // 生命周期：视图出现时初始化桌面歌词控制器
        .onAppear {
            DesktopLyricsController.shared.setup(with: playerService)
        }
        // 歌词页切换动画
        .animation(.easeInOut(duration: 0.3), value: showLyricsPage)
        
        // 监听歌曲 ID 变化，异步加载封面
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtworkData = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtworkData = nil
            }
        }
        
        // Touch Bar 默认显示内容
        .touchBar {
            Text(playerService.currentLyric.isEmpty ? (playerService.currentSong?.title ?? "Soloist") : playerService.currentLyric)
                .font(.headline)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 打开系统文件夹选择器
    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "请选择存储 MP3 的文件夹"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                libraryService.scanAndSavePermission(at: url)
            }
        }
    }
}

// MARK: - Subviews

/// 动态背景视图
///
/// 根据当前播放的歌曲封面生成高斯模糊背景，无封面时显示默认极光渐变。
struct HomeBackgroundView: View {
    let artworkData: Data?
    
    var body: some View {
            GeometryReader { geo in
                Group {
                    if let data = artworkData,
                       let nsImage = NSImage(data: data) {
                        // 方案 A: 有封面 -> Metal 加速模糊
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .drawingGroup() // 依然保留 Metal，但现在每首歌只调用一次
                            .blur(radius: 80)
                            .overlay(Color.black.opacity(0.2))
                    } else {
                        // 方案 B: 无封面 -> 静态渐变
                        ZStack {
                            Color(nsColor: .windowBackgroundColor)
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 400, height: 400)
                                .blur(radius: 100)
                                .offset(x: -100, y: -100)
                            
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 300, height: 300)
                                .blur(radius: 80)
                                .offset(x: 200, y: 100)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
#Preview {
    MacHomeView()
}
