//
//  MacHomeView.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

struct MacHomeView: View {
    // 1. 实例化我们在 Core 里写的服务
    // @StateObject 意味着这个对象随 View 的生命周期存在
    @StateObject private var libraryService = LocalLibraryService()
    // @StateObject 保证这个对象在 View 存活期间一直存在
        @StateObject private var playerService = AudioPlayerService()
    
    var body: some View {
        // 2. 左右分栏布局 (Mac 经典布局)
        NavigationSplitView {
            // 左侧：侧边栏 (Sidebar)
            List {
                Button("扫描文件夹") {
                    openFolderPicker()
                }
                .buttonStyle(.borderedProminent) // 显眼的按钮风格
                .padding(.vertical)
                
                // 显示扫描到的歌曲数量
                Text("共找到 \(libraryService.songs.count) 首歌")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250)
            
        } detail: {
            // 右侧：歌曲列表 (Detail)
            if libraryService.songs.isEmpty {
                Text("请点击左侧按钮扫描音乐文件夹")
                    .foregroundStyle(.secondary)
            } else {
                // 3. 渲染歌曲列表
                List(libraryService.songs) { song in
                    HStack {
                        // 暂时用系统图标代替封面
                        Image(systemName: "music.note")
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                                .foregroundColor(playerService.currentSong?.id == song.id ? .blue : .primary)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                                                
                        // 播放图标状态
                        if playerService.currentSong?.id == song.id && playerService.isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle()) // 扩大点击区域
                    .onTapGesture {
                        // 交互：点击列表项，调用后端播放
                        playerService.play(song: song)
                    }
                }
            }
        }
    }
    
    // 打开文件夹选择面板 (Mac 专属逻辑)
    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "请选择存储 MP3 的文件夹"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // 调用 Service 开始干活
                libraryService.scanAndSavePermission(at: url)
            }
        }
    }
}

// 预览代码 (供 Xcode 右侧画板使用)
#Preview {
    MacHomeView()
}
