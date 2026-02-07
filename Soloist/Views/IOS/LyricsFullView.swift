//
//  LyricsFullView.swift
//  Soloist
//
//  Created by Bole on 2026/2/7.
//

import SwiftUI

struct LyricsFullView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    let artworkData: Data?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 背景层 (复用背景组件，保持统一)
                IOSBackgroundView(artworkData: artworkData)
                    .overlay(.regularMaterial) // 叠加一层磨砂，让背景更深沉
                
                // 2. 内容层
                VStack(spacing: 30) {
                    // 顶部收起栏
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 10)
                        .onTapGesture { showLyrics = false }
                    
                    // 封面区
                    if let data = artworkData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                            .cornerRadius(20)
                            .shadow(radius: 20)
                    } else {
                        // 无封面占位
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                            .overlay(Image(systemName: "music.note").font(.system(size: 80)).foregroundColor(.white.opacity(0.5)))
                    }
                    
                    // 歌名歌手
                    VStack(spacing: 8) {
                        Text(playerService.currentSong?.title ?? "")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text(playerService.currentSong?.artist ?? "")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // 歌词滚动区 (复用 Shared 组件)
                    ScrollingLyricsView(
                        playerService: playerService,
                        activeFontSize: 28, // 手机上字号调小一点
                        inactiveFontSize: 18,
                        alignment: .center
                    )
                    
                    // 底部控制区 (复用 Shared 组件)
                    PlaybackControls(playerService: playerService, size: 40)
                        .foregroundColor(.white)
                        .padding(.bottom, 50)
                }
                .padding(.top, 20)
            }
        }
        // 下滑手势关闭
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 100 {
                    showLyrics = false
                }
            }
        )
    }
}

#Preview("Lyrics Page") {
    LyricsFullView(
        playerService: AudioPlayerService.shared,
        showLyrics: .constant(true),
        artworkData: nil // 预览时暂时传空，显示占位图
    )
}
