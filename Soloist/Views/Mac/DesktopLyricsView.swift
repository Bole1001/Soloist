//
//  DesktopLyricsView.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import SwiftUI

struct DesktopLyricsView: View {
    @ObservedObject var playerService: AudioPlayerService
    
    var body: some View {
        VStack {
            // ✨ 逻辑优化：
            // 如果有歌词 -> 显示歌词
            // 如果没歌词 -> 显示歌词占位符或 App 名字，让用户知道窗口还在
            Text(playerService.currentLyric.isEmpty ? "Soloist" : playerService.currentLyric)
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(.white)
                // 桌面歌词必须有阴影，否则在白色壁纸上看不见
                .shadow(color: .black, radius: 2, x: 1, y: 1)
                .multilineTextAlignment(.center)
                // 增加一点动画，让歌词切换不生硬
                .animation(.easeInOut(duration: 0.2), value: playerService.currentLyric)
                // 增加内边距，防止文字阴影被窗口边缘裁剪
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 这一行很重要：让点击文字本身也能穿透（结合 Controller 的设置）
        // 或者保留默认，让文字可以被拖拽
        .background(Color.clear)
    }
}
