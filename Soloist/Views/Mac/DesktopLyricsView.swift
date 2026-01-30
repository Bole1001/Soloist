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
                Text("")
                    .font(.system(size: 40, weight: .heavy)) // 字号加大到 40
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 2, y: 2) // 加阴影
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
