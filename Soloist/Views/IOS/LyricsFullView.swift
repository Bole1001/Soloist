//
//  LyricsFullView.swift
//  Soloist
//
//  Created by Bole on 2026/2/7.
//

import SwiftUI

struct LyricsFullView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    let artworkData: Data?
    
    // 沉浸式模式切换状态
    @State private var isImmersive = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 背景层
                IOSBackgroundView(artworkData: artworkData)
                    .overlay(.ultraThinMaterial)
                    .overlay(Color.black.opacity(isImmersive ? 0.6 : 0.45)) // 沉浸模式下背景稍暗，突出歌词
                
                // 2. 内容层
                VStack(spacing: 0) {
                    // 顶部收起栏
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                        .onTapGesture { showLyrics = false }

                    // 封面与歌曲信息区 (永远居中，自然收缩不遮挡)
                    VStack(spacing: isImmersive ? 15 : 25) {
                        // 封面
                        if let data = artworkData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    // 沉浸模式下缩小为 100x100 的居中图标
                                    width: isImmersive ? 100 : geometry.size.width * 0.8,
                                    height: isImmersive ? 100 : geometry.size.width * 0.8
                                )
                                .cornerRadius(isImmersive ? 12 : 20)
                                .shadow(radius: isImmersive ? 10 : 20)
                        } else {
                            RoundedRectangle(cornerRadius: isImmersive ? 12 : 20)
                                .fill(Color.white.opacity(0.1))
                                .frame(
                                    width: isImmersive ? 100 : geometry.size.width * 0.8,
                                    height: isImmersive ? 100 : geometry.size.width * 0.8
                                )
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: isImmersive ? 40 : 80))
                                        .foregroundColor(.white.opacity(0.5))
                                )
                        }
                        
                        // 歌名歌手
                        VStack(spacing: 8) {
                            Text(playerService.currentSong?.title ?? "未知曲目")
                                .font(isImmersive ? .title3.bold() : .title2.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(playerService.currentSong?.artist ?? "未知艺术家")
                                .font(isImmersive ? .subheadline : .body)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 30)
                    // 点击整个上半部区域都能触发动画
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isImmersive.toggle()
                        }
                    }
                    
                    // 歌词区强制居中
                    ScrollingLyricsView(
                        playerService: playerService,
                        activeFontSize: isImmersive ? 32 : 28,
                        inactiveFontSize: isImmersive ? 20 : 18,
                        alignment: .center // 保持居中排版
                    )
                    .padding(.vertical, 20)
                    .frame(maxHeight: .infinity) // 撑开中间的所有空间

                    // 自定义的精美进度条 + 时间
                    VStack(spacing: 12) {
                        SleekSlider(
                            currentTime: $playerService.currentTime,
                            duration: playerService.duration,
                            onSeek: { time in
                                playerService.seek(to: time)
                            }
                        )
                        
                        HStack {
                            Text(formatTime(playerService.currentTime))
                            Spacer()
                            Text(formatTime(playerService.duration))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)

                    // 底部控制区
                    PlaybackControls(playerService: playerService, size: 40)
                        .foregroundColor(.white)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 20 : 40)
                }
            }
        }
        // 下滑手势关闭
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 100 { showLyrics = false }
            }
        )
    }
    
    // 时间格式化防崩处理
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: 自定义极简进度条组件
struct SleekSlider: View {
    @Binding var currentTime: Double
    var duration: Double
    var onSeek: (Double) -> Void
    
    // 用于拖动时临时保存进度，防止和播放器的自动刷新冲突
    @State private var dragProgress: Double? = nil
    
    var body: some View {
        GeometryReader { geo in
            let currentProgress = dragProgress ?? (duration > 0 ? currentTime / duration : 0)
            
            ZStack(alignment: .leading) {
                // 底层半透明轨道 (高度 5)
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 5)
                
                // 走过的白色轨道 (高度 5)
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, geo.size.width * CGFloat(currentProgress)), height: 5)
                
                // 超小巧的滑块 (直径 8)
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    // 让圆心对齐进度的末端
                    .offset(x: max(0, geo.size.width * CGFloat(currentProgress)) - 4)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            // 整个 ZStack 高度设为 20，这样手指好点，但视觉上依然很细
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 拖动中，更新本地临时进度
                        let percentage = min(max(0, value.location.x / geo.size.width), 1)
                        dragProgress = percentage
                    }
                    .onEnded { value in
                        // 松手时，计算最终时间并传给播放器跳转
                        let percentage = min(max(0, value.location.x / geo.size.width), 1)
                        dragProgress = nil
                        onSeek(percentage * duration)
                    }
            )
        }
        // 限制外部占位高度
        .frame(height: 20)
    }
}
