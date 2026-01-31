//
//  MacHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

struct MacHomeView: View {
    @StateObject private var libraryService = LocalLibraryService()
    @StateObject private var playerService = AudioPlayerService.shared
    @State private var showLyricsPage = false
    @State private var selection: String? = "all"
    
    var body: some View {
        ZStack {
            
            // --- 图层 1: 主界面 ---
            NavigationSplitView {
                // === 左侧：侧边栏 (保持清爽) ===
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
                // 侧边栏底部工具栏
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        Button(action: { openFolderPicker() }) {
                            Image(systemName: "plus").fontWeight(.bold)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .help("添加音乐文件夹")
                        
                        Spacer()
                        Text("\(libraryService.songs.count) 首歌").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Color.clear.frame(width: 14, height: 14)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                    .overlay(Divider(), alignment: .top)
                }
                
            } detail: {
                // === 右侧：沉浸式内容详情 ===
                ZStack {
                    // ✨ 1. 动态毛玻璃背景层
                    HomeBackgroundView(playerService: playerService)
                    
                    // ✨ 2. 内容层
                    VStack(spacing: 0) {
                        if libraryService.songs.isEmpty {
                            // 空状态
                            VStack(spacing: 16) {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.tertiary)
                                Text("暂无音乐").font(.title2).fontWeight(.medium)
                                Text("点击左下角的 + 号添加文件夹").font(.subheadline).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            // 即使是空状态，也要给文字加点阴影，防止背景太亮看不清
                            .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                        } else {
                            // 歌曲列表
                            List {
                                ForEach(libraryService.songs) { song in
                                    SongListRow(song: song, playerService: playerService, playlist: libraryService.songs)
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.inset)
                            // ✨ 关键：隐藏列表自带的白色背景，让毛玻璃透出来
                            .scrollContentBackground(.hidden)
                        }
                        
                        // 底部播放控制条
                        if playerService.currentSong != nil {
                            PlayerControlBar(
                                playerService: playerService,
                                showLyrics: $showLyricsPage
                            )
                            .frame(height: 80)
                            // 控制条也用超薄材质，与背景融合
                            .background(.ultraThinMaterial)
                            .overlay(Divider().opacity(0.5), alignment: .top)
                            .transition(.move(edge: .bottom))
                        }
                    }
                }
            }
            
            // --- 图层 2: 歌词全屏页 (Overlay) ---
            if showLyricsPage {
                LyricsFullView(
                    playerService: playerService,
                    showLyrics: $showLyricsPage
                )
                .transition(.move(edge: .bottom))
                .zIndex(1)
            }
        }
        .onAppear {
            DesktopLyricsController.shared.setup(with: playerService)
        }
        .animation(.easeInOut(duration: 0.3), value: showLyricsPage)
        
        .touchBar {
            Text(playerService.currentLyric.isEmpty ? (playerService.currentSong?.title ?? "Soloist") : playerService.currentLyric)
                .font(.headline)
        }
    }
    
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

// ✨ 新组件：专门负责渲染首页的动态背景
struct HomeBackgroundView: View {
    @ObservedObject var playerService: AudioPlayerService
    
    // ✨ 1. 新增：暂存当前加载好的背景图
    @State private var currentArtwork: Data? = nil
    
    var body: some View {
        GeometryReader { geo in
            Group {
                // ✨ 2. 修改：读本地 State
                if let data = currentArtwork,
                   let nsImage = NSImage(data: data) {
                    // 方案 A: 有封面，显示高斯模糊
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        // 使用 GPU 渲染模糊，避免卡顿
                        .drawingGroup()
                        .blur(radius: 80)
                        .overlay(Color.black.opacity(0.2))
                } else {
                    // 方案 B: 没封面，显示高级的渐变极光色
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
        // ✨ 3. 核心：监听切歌，异步加载背景图
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                currentArtwork = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtwork = nil
            }
        }
    }
}

// ✨ 升级版：歌曲行视图 (适配深色/模糊背景)
struct SongListRow: View {
    let song: Song
    @ObservedObject var playerService: AudioPlayerService
    let playlist: [Song]
    
    // ✨ 1. 新增：每一行自己维护自己的小封面
    @State private var rowArtwork: Data? = nil
    
    var isPlayingThis: Bool {
        playerService.currentSong?.id == song.id
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // 1. 封面图区域
            ZStack {
                // ✨ 2. 修改：读本地 State
                if let data = rowArtwork, let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            // ✨ 3. 核心：只有这一行出现在屏幕上时，才去读图片
            .task {
                // 这是一个微小的优化：如果已经有图了就不读了
                if rowArtwork == nil {
                    rowArtwork = await ArtworkLoader.loadArtwork(for: song)
                }
            }
            
            // 2. 文字信息
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.1), radius: 1)
                
                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 3. 状态图标
            if isPlayingThis {
                Image(systemName: playerService.isPlaying ? "speaker.wave.3.fill" : "speaker.fill")
                    .foregroundStyle(.white)
                    .font(.title3)
                    .shadow(color: .blue, radius: 5)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        // 选中态样式
        .padding(.horizontal, 4)
        .background(
            ZStack {
                if isPlayingThis {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.2))
                }
            }
        )
        .padding(.horizontal, 12)
        .onTapGesture {
            playerService.play(song: song, playlist: playlist)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

#Preview {
    MacHomeView()
}
