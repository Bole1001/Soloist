//
//  LyricsFullView.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import SwiftUI

struct LyricsFullView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    
    var body: some View {
        ZStack {
            // 1. 复用背景组件
            ArtworkBackgroundView(song: playerService.currentSong)
            
            // 2. 内容层
            HStack(spacing: 60) {
                
                // === 左侧：封面 + 控制按钮 ===
                VStack(spacing: 40) {
                    // 复用封面组件 (大尺寸)
                    ArtworkView(song: playerService.currentSong, size: 320)
                        .shadow(radius: 20)
                        .onTapGesture {
                            withAnimation { showLyrics = false }
                        }
                        .help("点击收起歌词页")
                    
                    // 复用控制按钮组件 (大尺寸)
                    HStack(spacing: 40) {
                        PlaybackControls(playerService: playerService, size: 50)
                            .foregroundColor(.white) // 强制白色以适应深色背景
                    }
                }
                
                // === 右侧：复用歌词列表组件 ===
                ScrollingLyricsView(
                    playerService: playerService,
                    activeFontSize: 32,
                    inactiveFontSize: 20,
                    alignment: .leading
                )
                .frame(maxWidth: 500)
            }
            .padding(40)
        }
        .background(Color.black)
    }
}
