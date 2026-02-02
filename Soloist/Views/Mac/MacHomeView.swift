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
    
    var body: some View {
        ZStack {
            
            // MARK: - Layer 1: 主导航界面
            NavigationSplitView {
                // === 左侧：侧边栏 ===
                List(selection: $selection) {
                    Section {
                        NavigationLink(value: "all") {
                            Label("所有音乐", systemImage: "music.note.list")
                        }
                    } header: {
                        Text("资料库").font(.headline)
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
                
                // 侧边栏底部工具栏 (添加按钮 & 计数)
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        // 添加文件夹按钮
                        Button(action: { openFolderPicker() }) {
                            Image(systemName: "plus").fontWeight(.bold)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .help("添加音乐文件夹")
                        
                        Spacer()
                        
                        // 歌曲数量统计
                        Text("\(libraryService.songs.count) 首歌")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 占位符以保持布局平衡
                        Color.clear.frame(width: 14, height: 14)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                    .overlay(Divider(), alignment: .top)
                }
                
            } detail: {
                // === 右侧：详情内容区域 ===
                ZStack {
                    // 1. 动态毛玻璃背景层 (随封面变化)
                    HomeBackgroundView(playerService: playerService)
                    
                    // 2. 内容层 (列表 + 空状态)
                    VStack(spacing: 0) {
                        if libraryService.songs.isEmpty {
                            // 空状态视图
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.tertiary)
                                Text("暂无音乐").font(.title2).fontWeight(.medium)
                                Text("点击左下角的 + 号添加文件夹")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        } else {
                            // 歌曲列表视图
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
                            // 隐藏默认白色背景，透出下方的毛玻璃效果
                            .scrollContentBackground(.hidden)
                        }
                        
                        // 底部播放控制条 (悬浮在列表下方)
                        if playerService.currentSong != nil {
                            PlayerControlBar(
                                playerService: playerService,
                                showLyrics: $showLyricsPage
                            )
                            .frame(height: 80)
                            .background(.ultraThinMaterial)
                            .overlay(Divider().opacity(0.5), alignment: .top)
                            .transition(.move(edge: .bottom))
                        }
                    }
                }
            }
            
            // MARK: - Layer 2: 全屏歌词页 (Overlay)
            // 覆盖在所有内容之上
            if showLyricsPage {
                LyricsFullView(
                    playerService: playerService,
                    showLyrics: $showLyricsPage
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
    @ObservedObject var playerService: AudioPlayerService
    
    /// 异步加载的封面数据缓存
    @State private var currentArtwork: Data? = nil
    
    var body: some View {
        GeometryReader { geo in
            Group {
                if let data = currentArtwork,
                   let nsImage = NSImage(data: data) {
                    // 方案 A: 有封面 -> 显示高斯模糊背景
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .drawingGroup() // 启用 Metal 渲染加速模糊计算
                        .blur(radius: 80)
                        .overlay(Color.black.opacity(0.2)) // 压暗处理，保证前景文字可读性
                } else {
                    // 方案 B: 无封面 -> 显示默认极光渐变
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
        // 监听歌曲 ID 变化，异步重新加载背景
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtwork = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtwork = nil
            }
        }
    }
}

#Preview {
    MacHomeView()
}
