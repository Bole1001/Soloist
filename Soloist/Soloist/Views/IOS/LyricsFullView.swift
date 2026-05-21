//
//  LyricsFullView.swift
//  Soloist
//
//  Created by Bole on 2026/2/7.
//

import SwiftUI
import Combine

struct LyricsFullView: View {
    @ObservedObject var playerService: AudioPlayerService
    @Binding var showLyrics: Bool
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    // 局部状态，专门控制播放列表弹窗的显示
    @State private var showQueueSheet: Bool = false
    let artworkData: Data?
    
    // 沉浸式模式切换状态
    @State private var isImmersive = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 背景层
                IOSBackgroundView(artworkData: artworkData)
                    .overlay(.ultraThinMaterial)
                    .overlay(Color.black.opacity(isImmersive ? 0.6 : 0.45)) // 沉浸模式下背景稍暗，突出歌词
                
                // 2. 内容层
                VStack(spacing: 0) {
                    // 顶部收起栏与操作按钮区
                    ZStack(alignment: .center) {
                        // 居中的收起手柄 (保持不变)
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 4)
                            .onTapGesture { showLyrics = false }
                        
                        HStack {
                            Spacer()
                            if let song = playerService.currentSong {
                                AddToPlaylistMenu(song: song) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 20, weight: .bold)) // 增加字重保证在复杂背景下的可读性，但不加圆圈
                                        .foregroundColor(.white.opacity(0.8)) // 稍微增加一点不透明度，保证可读
                                        .frame(width: 44, height: 44) // 保持 44pt 的达标触控热区
                                        .contentShape(Rectangle()) // 扩大点击判定范围
                                }
                                .buttonStyle(.plain) // 必须加，确保 Menu 样式干净
                            }
                        }
                        .padding(.trailing, 20) // 保持与边缘的距离
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 20)

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
                        alignment: .center, // 保持居中排版
                        isImmersive: isImmersive
                    )
                    .padding(.vertical, 20)
                    .frame(maxHeight: .infinity) // 撑开中间的所有空间

                    // 自定义的精美进度条 + 时间
                    PlayerProgressView(playerService: playerService)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 20)

                    // 底部控制区
                    PlaybackControls(
                        playerService: playerService,
                        size: 40,
                        onQueueTap: {
                            showQueueSheet = true
                        }
                    )
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
        // 监听 showQueueSheet 的变化，弹出半屏模态框
        .sheet(isPresented: $showQueueSheet) {
            QueuePage()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
struct PlayerProgressView: View {
    @ObservedObject var playerService: AudioPlayerService
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // 用于平滑显示的本地时间，脱离 playerService 的低频刷新
    @State private var smoothTime: Double = 0
    @GestureState private var dragProgress: Double? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. 细线进度条
            GeometryReader { geo in
                let duration = playerService.duration > 0 ? playerService.duration : 1
                let currentProgress = dragProgress ?? (smoothTime / duration)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, geo.size.width * CGFloat(currentProgress)), height: 5)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, geo.size.width * CGFloat(currentProgress)) - 4)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragProgress) { value, state, _ in
                            state = min(max(0, value.location.x / geo.size.width), 1)
                        }
                        .onChanged { value in
                            let percentage = min(max(0, value.location.x / geo.size.width), 1)
                            smoothTime = percentage * duration // 拖动时，时间文字实时跟着变
                        }
                        .onEnded { value in
                            let percentage = min(max(0, value.location.x / geo.size.width), 1)
                            let targetTime = percentage * duration
                            playerService.seek(to: targetTime)
                            smoothTime = targetTime
                        }
                )
            }
            .frame(height: 20)
            
            // 2. 时间文本
            HStack {
                Text(formatTime(smoothTime))
                Spacer()
                Text(formatTime(playerService.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white.opacity(0.6))
        }
        // 接收定时器信号，高频更新本地进度
        .onReceive(timer) { _ in
            if dragProgress == nil { // 只有在用户没拖动滑块时，才自动往前走
                smoothTime = playerService.currentTime
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let totalSeconds = max(0, Int(time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
