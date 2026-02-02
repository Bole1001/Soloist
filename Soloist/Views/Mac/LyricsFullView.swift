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
        // 1. 引入 GeometryReader 获取父容器尺寸，实现响应式布局
        GeometryReader { geometry in
            
            // 设定布局断点：宽度小于 700 则视为窄屏模式
            let isCompact = geometry.size.width < 700
            
            // 动态计算封面尺寸：
            // 窄屏：取屏幕宽度的 60%
            // 宽屏：取固定 320 或屏幕高度的 40% (取较小值)，防止在矮窗口中过大
            let artworkSize: CGFloat = isCompact
                ? geometry.size.width * 0.6
                : min(320, geometry.size.height * 0.4)
            
            ZStack {
                // MARK: - 背景层
                ArtworkBackgroundView(song: playerService.currentSong)
                
                // MARK: - 内容层
                // 使用 AnyLayout 根据状态动态切换布局容器 (HStack <-> VStack)
                let layout = isCompact ? AnyLayout(VStackLayout(spacing: 30)) : AnyLayout(HStackLayout(spacing: 60))
                
                layout {
                    
                    // === 第一部分：左侧/顶部 (封面与控制) ===
                    VStack(spacing: isCompact ? 20 : 40) {
                        // 封面组件 (尺寸动态化)
                        ArtworkView(song: playerService.currentSong, size: artworkSize)
                            .shadow(radius: 20)
                            .onTapGesture {
                                withAnimation { showLyrics = false }
                            }
                            .help("点击收起歌词页")
                        
                        // 播放控制栏
                        HStack(spacing: 40) {
                            // 窄屏时稍微缩小按钮尺寸
                            PlaybackControls(playerService: playerService, size: isCompact ? 40 : 50)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // === 第二部分：右侧/底部 (歌词列表) ===
                    ScrollingLyricsView(
                        playerService: playerService,
                        activeFontSize: isCompact ? 24 : 32, // 窄屏减小字号
                        inactiveFontSize: isCompact ? 16 : 20,
                        alignment: isCompact ? .center : .leading // 窄屏居中，宽屏左对齐
                    )
                    // 宽屏限制宽度，窄屏占满宽度
                    .frame(maxWidth: isCompact ? .infinity : 500)
                    // 窄屏限制高度，防止歌词挤压封面
                    .frame(maxHeight: isCompact ? geometry.size.height * 0.4 : .infinity)
                }
                .padding(40)
                // 强制内容层占满 GeometryReader 提供的空间，确保居中
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(Color.black)
        }
    }
}
