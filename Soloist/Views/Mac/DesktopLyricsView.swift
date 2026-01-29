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
            if !playerService.currentLyric.isEmpty {
                Text(playerService.currentLyric)
                    .font(.system(size: 40, weight: .heavy)) // 字号加大到 40
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 2, y: 2) // 加阴影
                    .multilineTextAlignment(.center)
            } else {
                // 如果没歌词，显示这个，证明窗口存在
                Text("桌面歌词测试")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .background(Color.black.opacity(0.5)) // 给字加个黑底
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
