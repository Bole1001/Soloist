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
    
    var body: some View {
        ZStack {
            // --- 1. 背景层 (模糊图 或 渐变色) ---
            if let data = playerService.currentSong?.artworkData,
               let nsImage = NSImage(data: data) {
                GeometryReader { geo in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.4))
                }
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
                    if let data = playerService.currentSong?.artworkData,
                       let nsImage = NSImage(data: data) {
                        // A. 有封面
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 320, height: 320)
                            .cornerRadius(12)
                            .shadow(radius: 20)
                            // ✨ 新增：点击封面关闭歌词页
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
                        // ✨ 新增：点击占位图也能关闭
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
                                VStack(alignment: .leading, spacing: 30) {
                                    ForEach(playerService.lyrics) { line in
                                        Text(line.text)
                                            .font(.system(size: isCurrentLine(line) ? 32 : 20,
                                                          weight: isCurrentLine(line) ? .bold : .medium))
                                            .foregroundColor(isCurrentLine(line) ? .white : .white.opacity(0.4))
                                            .animation(.spring(), value: playerService.currentLyric)
                                            .id(line.id)
                                            .onTapGesture {
                                                // 预留点击功能
                                            }
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
            
            // (右上角的关闭按钮已删除)
        }
        .background(Color.black)
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
