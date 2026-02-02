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
            // 显示当前歌词，若为空则显示应用名称作为占位符
            Text(playerService.currentLyric.isEmpty ? "Soloist" : playerService.currentLyric)
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(.white)
                // 添加阴影以确保在亮色背景或壁纸上保持可读性
                .shadow(color: .black, radius: 2, x: 1, y: 1)
                .multilineTextAlignment(.center)
                // 歌词文本变化时的平滑过渡动画
                .animation(.easeInOut(duration: 0.2), value: playerService.currentLyric)
                // 增加内边距，防止文字阴影被窗口边缘裁剪
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 使用极低透明度的背景以拦截鼠标事件，支持拖拽操作
        // 注意：纯 Color.clear 会导致鼠标事件直接穿透窗口，无法进行拖动
        .background(Color.black.opacity(0.01))
    }
}
