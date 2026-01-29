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
    
    var body: some View {
        // ✨ 修改点 1: 最外层用 ZStack 包裹，为了做图层叠加
        ZStack {
            
            // --- 图层 1: 主界面 (SplitView) ---
            NavigationSplitView {
                // 左侧：侧边栏
                List {
                    Button("扫描文件夹") {
                        openFolderPicker()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical)
                    
                    Text("共找到 \(libraryService.songs.count) 首歌")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
                
            } detail: {
                // 右侧：内容详情
                VStack(spacing: 0) {
                    
                    // 歌曲列表区域
                    if libraryService.songs.isEmpty {
                        Text("请点击左侧按钮扫描音乐文件夹")
                            .foregroundStyle(.secondary)
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
                            showLyrics: $showLyricsPage // 传入绑定
                        )
                        .frame(height: 80)
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            
            // --- 图层 2: 歌词全屏页 (Overlay) ---
            // ✨ 修改点 2: 不再用 .sheet，而是直接覆盖在上面
            if showLyricsPage {
                LyricsFullView(
                    playerService: playerService,
                    showLyrics: $showLyricsPage // 传入绑定，让它可以关闭自己
                )
                // ✨ 动画效果：从底部升起
                .transition(.move(edge: .bottom))
                .zIndex(1) // 确保在最上层
            }
        }
        // ✨ 修改点 3: 绑定动画，当 showLyricsPage 变化时自动播放过渡动画
        .animation(.easeInOut(duration: 0.3), value: showLyricsPage)
        
        // ✨✨✨ 新增功能：Touch Bar 支持 ✨✨✨
        .touchBar {
            // 1. 歌词显示 (最左侧，或者系统自动布局)
            // 逻辑：如果有歌词显示歌词，没有歌词显示歌名
            Text(playerService.currentLyric.isEmpty ? (playerService.currentSong?.title ?? "Soloist") : playerService.currentLyric)
                .font(.headline)
            
            // 2. 控制按钮 (上一首 - 播放/暂停 - 下一首)
            Button(action: { playerService.previous() }) {
                Image(systemName: "backward.fill")
            }
            
            Button(action: { playerService.togglePlayPause() }) {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
            }
            
            Button(action: { playerService.next() }) {
                Image(systemName: "forward.fill")
            }
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
