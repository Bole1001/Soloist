//
//  SongListRow.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// 🔧 适配层
#if os(macOS)
import AppKit
typealias SongRowImage = NSImage
#else
import UIKit
typealias SongRowImage = UIImage
#endif

// ✨ 升级版通用组件：歌曲行视图
struct SongListRow: View {
    let song: Song
    @ObservedObject var playerService: AudioPlayerService
    
    // 注意：这里不需要传 playlist 了，因为列表可以从外部控制，
    // 或者你可以保留它，看你点击事件怎么写。这里暂时保留。
    let playlist: [Song]
    
    @State private var rowArtwork: Data? = nil
    
    var isPlayingThis: Bool {
        playerService.currentSong?.id == song.id
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // 1. 封面图区域
            ZStack {
                // ✨ 兼容修改：使用 SongRowImage
                if let data = rowArtwork, let image = SongRowImage(data: data) {
                    #if os(macOS)
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    #else
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    #endif
                } else {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            // 任务：异步加载
            .task(id: song.id) {
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
                    // 移除阴影优化 iOS 性能，或保留看你喜好
                    // .shadow(color: .black.opacity(0.1), radius: 1)
                
                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 3. 状态图标
            if isPlayingThis {
                Image(systemName: playerService.isPlaying ? "speaker.wave.3.fill" : "speaker.fill")
                    .foregroundStyle(.blue) // iOS 上可能 white 看不清，建议用 blue
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle()) // 扩大点击区域
        
        // --- 背景高亮逻辑 ---
        .background(
            ZStack {
                if isPlayingThis {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.1)) // 更加通用的高亮色
                }
            }
        )
        // 点击播放
        .onTapGesture {
            playerService.play(song: song, playlist: playlist)
        }
    }
}
