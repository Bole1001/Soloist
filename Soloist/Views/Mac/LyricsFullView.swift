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
    
    let artworkData: Data?
    
    var body: some View {
        GeometryReader { geometry in
            
            let isCompact = geometry.size.width < 700
            
            // 动态计算封面尺寸
            let artworkSize: CGFloat = isCompact
                ? geometry.size.width * 0.6
                : min(320, geometry.size.height * 0.4)
            
            ZStack {
                // MARK: - 1. 背景层
                Group {
                    if let data = artworkData, let nsImage = NSImage(data: data) {
                        // 方案 A: 有封面 -> 显示模糊的大图
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .drawingGroup() // Metal 加速渲染
                            .blur(radius: 80)
                    } else {
                        // 方案 B: 无封面 -> 静态极光背景
                        ZStack {
                            // 1. 底色：纯黑 (衬托光感)
                            Color.black
                            
                            // 2. 左上角光斑：使用青色 (Cyan)
                            Circle()
                                .fill(Color.cyan.opacity(0.6))
                                .frame(width: 500, height: 500)
                                .blur(radius: 120)
                                .offset(x: -150, y: -150)
                            
                            // 3. 右下角光斑
                            Circle()
                                .fill(Color.pink.opacity(0.6))
                                .frame(width: 400, height: 400)
                                .blur(radius: 100)
                                .offset(x: 200, y: 150)
                            
                            // 4. 深蓝
                            Circle()
                                .fill(Color.blue.opacity(0.4))
                                .frame(width: 600, height: 600)
                                .blur(radius: 150)
                        }
                        .drawingGroup()
                    }
                }
                .ignoresSafeArea()
                // 统一叠加一层黑色遮罩，增强文字对比度
                .overlay(Color.black.opacity(0.3))
                
                // MARK: - 2. 内容层
                let layout = isCompact ? AnyLayout(VStackLayout(spacing: 30)) : AnyLayout(HStackLayout(spacing: 60))
                
                layout {
                    // === 左侧：封面与控制 ===
                    VStack(spacing: isCompact ? 20 : 40) {
                        // 这里封面显示组件，如果 ArtworkView 内部支持 Data 就传 Data，
                        // 如果不支持，可能需要你修改 ArtworkView 让它也能像这样接收 data
                        ArtworkView(song: playerService.currentSong, size: artworkSize)
                            .shadow(radius: 20)
                            .onTapGesture {
                                withAnimation { showLyrics = false }
                            }
                            .help("点击收起歌词页")
                        
                        HStack(spacing: 40) {
                            PlaybackControls(playerService: playerService, size: isCompact ? 40 : 50)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // === 右侧：歌词列表 ===
                    ScrollingLyricsView(
                        playerService: playerService,
                        activeFontSize: isCompact ? 24 : 32,
                        inactiveFontSize: isCompact ? 16 : 20,
                        alignment: isCompact ? .center : .leading
                    )
                    .frame(maxWidth: isCompact ? .infinity : 500)
                    .frame(maxHeight: isCompact ? geometry.size.height * 0.4 : .infinity)
                }
                .padding(40)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(Color.black) // 兜底背景色
        }
    }
}
