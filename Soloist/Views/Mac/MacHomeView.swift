//
//  MacHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

struct MacHomeView: View {
    // 1. 负责扫描硬盘和管理文件权限
    @StateObject private var libraryService = LocalLibraryService()
    
    // 2. 负责播放音乐和控制逻辑
    @StateObject private var playerService = AudioPlayerService()
    
    // 3. 控制歌词页显示的开关
    @State private var showLyricsPage = false
    
    // 4. (UI优化) 侧边栏选中项
    @State private var selection: String? = "all"
    
    var body: some View {
        ZStack {
            
            // --- 图层 1: 主界面 (SplitView) ---
            NavigationSplitView {
                // === 左侧：侧边栏 ===
                List(selection: $selection) {
                    Section("资料库") {
                        NavigationLink(value: "all") {
                            Label("所有音乐", systemImage: "music.note.list")
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
                // ✨ 修复：使用 safeAreaInset 替代 toolbar(.bottomBar)
                // 这样可以把控件固定在侧边栏的最底部
                .safeAreaInset(edge: .bottom) {
                    HStack {
                        // 1. 添加文件夹按钮 (+)
                        Button(action: {
                            openFolderPicker()
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless) // 去掉默认按钮背景，更简洁
                        .help("添加音乐文件夹")
                        
                        Spacer()
                        
                        // 2. 歌曲数量统计
                        Text("\(libraryService.songs.count) 首歌")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // 为了视觉平衡，右边也占个位(或者留空)
                        Color.clear.frame(width: 14, height: 14)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(nsColor: .controlBackgroundColor)) // 保持和侧边栏背景一致
                    .overlay(Divider(), alignment: .top) // 顶部加一条细分割线
                }
                
            } detail: {
                // === 右侧：内容详情 ===
                VStack(spacing: 0) {
                    
                    // 歌曲列表区域
                    if libraryService.songs.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("暂无音乐")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("点击左下角的 + 号添加文件夹")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(libraryService.songs) { song in
                            HStack {
                                // 封面
                                if let data = song.artworkData, let nsImage = NSImage(data: data) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(4)
                                        .clipped()
                                } else {
                                    Image(systemName: "music.note")
                                        .frame(width: 40, height: 40)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                // 歌名与歌手
                                VStack(alignment: .leading) {
                                    Text(song.title)
                                        .font(.headline)
                                        .foregroundColor(playerService.currentSong?.id == song.id ? .blue : .primary)
                                    Text(song.artist)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // 播放状态图标
                                if playerService.currentSong?.id == song.id && playerService.isPlaying {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playerService.play(song: song, playlist: libraryService.songs)
                            }
                        }
                    }
                    
                    // 底部播放控制条
                    if playerService.currentSong != nil {
                        PlayerControlBar(
                            playerService: playerService,
                            showLyrics: $showLyricsPage
                        )
                        .frame(height: 80)
                        .transition(.move(edge: .bottom))
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
        .animation(.easeInOut(duration: 0.3), value: showLyricsPage)
        
        // Touch Bar 支持
        .touchBar {
            Text(playerService.currentLyric.isEmpty ? (playerService.currentSong?.title ?? "Soloist") : playerService.currentLyric)
                .font(.headline)
        }
    }
    
    // 打开文件夹选择面板
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

#Preview {
    MacHomeView()
}
