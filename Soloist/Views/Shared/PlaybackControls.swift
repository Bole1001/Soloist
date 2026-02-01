//
//  PlaybackControls.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

struct PlaybackControls: View {
    @ObservedObject var playerService: AudioPlayerService
    
    // 允许外部传入尺寸 (你原代码里图标大小不一，这里统一用比例控制，保持原样风格)
    let size: CGFloat
    
    var body: some View {
        HStack(spacing: size * 0.6) { // 间距按比例缩放
            // 1. 上一首 (对应原代码 Button action: playerService.previous())
            Button(action: { playerService.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: size * 0.6)) // 原代码 .title3 约等于 20-24pt
            }
            .buttonStyle(.plain)
            
            // 2. 播放/暂停 (对应原代码 Button action: playerService.togglePlayPause())
            Button(action: { playerService.togglePlayPause() }) {
                Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: size * 1.2)) // 原代码 38pt
            }
            .buttonStyle(.plain)
            
            // 3. 下一首 (对应原代码 Button action: playerService.next())
            Button(action: { playerService.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: size * 0.6))
            }
            .buttonStyle(.plain)
        }
    }
}
