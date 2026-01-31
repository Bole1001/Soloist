//
//  LyricsFullView.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import SwiftUI

struct LyricsFullView: View {
    @ObservedObject var playerService: AudioPlayerService
    
    // 接收父视图传来的开关，用来手动关闭自己
    @Binding var showLyrics: Bool
    
    // ✨ 1. 新增：用于存储异步加载的高清封面
    @State private var currentArtwork: Data? = nil
    
    var body: some View {
        ZStack {
            // --- 1. 背景层 (模糊大图) ---
            // ✨ 2. 修改：读取本地 State 里的图片
            if let data = currentArtwork,
               let nsImage = NSImage(data: data) {
                GeometryReader { geo in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        // 强制使用 GPU 渲染模糊，极大减少 CPU 发热和卡顿
                        .drawingGroup()
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                }
                .ignoresSafeArea()
            } else {
                // 没图时的默认背景
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(white: 0.2), Color.black]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
            }
            
            // --- 2. 内容层 ---
            HStack(spacing: 60) {
                
                // === 左侧：封面 + 控制按钮 ===
                VStack(spacing: 40) {
                    // 封面区域
                    // ✨ 3. 修改：读取本地 State 里的图片
                    if let data = currentArtwork,
                       let nsImage = NSImage(data: data) {
                        // A. 有封面
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .cornerRadius(12)
                            .shadow(radius: 20)
                            .onTapGesture {
                                withAnimation {
                                    showLyrics = false
                                }
                            }
                            .help("点击收起歌词页")
                    } else {
                        // B. 没封面 (占位图)
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 320, height: 320)
                                .shadow(radius: 20)
                            
                            Image(systemName: "music.quarternote.3")
                                .font(.system(size: 120))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .onTapGesture {
                            withAnimation {
                                showLyrics = false
                            }
                        }
                        .help("点击收起歌词页")
                    }
                    
                    // 控制按钮组
                    HStack(spacing: 40) {
                        Button(action: { playerService.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { playerService.togglePlayPause() }) {
                            Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { playerService.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // === 右侧：滚动歌词列表 ===
                VStack {
                    if playerService.lyrics.isEmpty {
                        Text("暂无歌词")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                // LazyVStack 只渲染看得到的歌词，解决长列表卡顿问题
                                LazyVStack(alignment: .leading, spacing: 30) {
                                    ForEach(playerService.lyrics) { line in
                                        Text(line.text)
                                            .font(.system(size: isCurrentLine(line) ? 32 : 20,
                                                          weight: isCurrentLine(line) ? .bold : .medium))
                                            .foregroundColor(isCurrentLine(line) ? .white : .white.opacity(0.4))
                                            // 稍微调快动画，减少拖泥带水的感觉
                                            .animation(.easeInOut(duration: 0.2), value: playerService.currentLyric)
                                            .id(line.id)
                                    }
                                }
                                .padding(.vertical, 300)
                            }
                            .onChange(of: playerService.currentLyric) {
                                scrollToCurrentLine(proxy: proxy)
                            }
                        }
                    }
                }
                .frame(maxWidth: 500)
            }
            .padding(40)
        }
        .background(Color.black)
        // ✨ 4. 核心逻辑：监听切歌事件，异步加载高清大图
        .task(id: playerService.currentSong?.id) {
            if let song = playerService.currentSong {
                // 只有在打开歌词大图页面时，才去加载这张大图，极大节省内存
                currentArtwork = await ArtworkLoader.loadArtwork(for: song)
            } else {
                currentArtwork = nil
            }
        }
    }
    
    func isCurrentLine(_ line: LyricLine) -> Bool {
        return playerService.currentLyric == line.text
    }
    
    func scrollToCurrentLine(proxy: ScrollViewProxy) {
        if let currentLine = playerService.lyrics.first(where: { $0.text == playerService.currentLyric }) {
            withAnimation {
                proxy.scrollTo(currentLine.id, anchor: .center)
            }
        }
    }
}
