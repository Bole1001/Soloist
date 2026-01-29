//
//  LyricsFullView.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import SwiftUI

struct LyricsFullView: View {
    @ObservedObject var playerService: AudioPlayerService
    
    // ✨ 修改点 1: 接收父视图传来的开关，用来手动关闭自己
    @Binding var showLyrics: Bool
    
    var body: some View {
        ZStack {
            // --- 1. 背景层 (模糊的封面大图) ---
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
                Color.black.opacity(0.9)
            }
            
            // --- 2. 内容层 ---
            HStack(spacing: 40) {
                // 左侧：清晰的专辑封面
                if let data = playerService.currentSong?.artworkData,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 20)
                }
                
                // 右侧：滚动歌词列表
                VStack {
                    if playerService.lyrics.isEmpty {
                        Text("暂无歌词")
                            .font(.title)
                            .foregroundColor(.gray)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 25) {
                                    ForEach(playerService.lyrics) { line in
                                        Text(line.text)
                                            .font(.system(size: isCurrentLine(line) ? 28 : 18,
                                                          weight: isCurrentLine(line) ? .bold : .regular))
                                            .foregroundColor(isCurrentLine(line) ? .white : .white.opacity(0.5))
                                            .animation(.spring(), value: playerService.currentLyric)
                                            .id(line.id)
                                            .onTapGesture {
                                                // (可选) 点击跳转
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
            
            // --- 3. 关闭按钮 (右上角) ---
            VStack {
                HStack {
                    Spacer()
                    // ✨ 修改点 2: 点击关闭时，把变量设为 false，带动画关闭
                    Button(action: {
                        withAnimation {
                            showLyrics = false
                        }
                    }) {
                        Image(systemName: "chevron.down.circle.fill") // 换个向下的箭头图标表示收起
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(30)
        }
        // 去掉了 .frame(minWidth...) 限制，让它自适应父容器
        .background(Color.black) // 防止透视到底部列表
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
