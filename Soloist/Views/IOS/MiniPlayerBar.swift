//
//  MiniPlayerBar.swift
//  Soloist
//
//  Created by Bole on 2026/2/7.
//

import SwiftUI

/// iOS 专用的紧凑型播放条
struct MiniPlayerBar: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ArtworkView(song: playerService.currentSong, size: 48)
                .shadow(radius: 4)
            
            // 信息区 (点击展开)
            VStack(alignment: .leading, spacing: 2) {
                Text(playerService.currentSong?.title ?? "Soloist")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(playerService.currentSong?.artist ?? "未播放")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                showLyrics = true
            }
            
            // 控制区
            HStack(spacing: 16) {
                Button(action: { playerService.togglePlayPause() }) {
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Button(action: { playerService.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

#Preview("Mini Player") {
    ZStack {
        // 给个背景色方便看清毛玻璃效果
        Color.gray
        
        VStack {
            Spacer()
            // 使用 .constant(false) 模拟绑定
            MiniPlayerBar(showLyrics: .constant(false))
                .environmentObject(AudioPlayerService.shared)
        }
    }
}
