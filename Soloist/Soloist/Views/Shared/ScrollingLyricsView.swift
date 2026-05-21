//
//  ScrollingLyricsView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

/// 滚动歌词视图 (ScrollingLyricsView)
///
/// **职责**: 显示同步滚动的歌词列表。
/// **特性**:
/// 1. **精准高亮**: 基于时间戳判断当前行，完美支持重复歌词（如副歌）。
/// 2. **视觉优化**: 顶部底部增加渐变遮罩，滚动更自然。
/// 3. **交互跳转**: 点击歌词可直接调整进度。
struct ScrollingLyricsView: View {
    
    @ObservedObject var playerService: AudioPlayerService
    
    var activeFontSize: CGFloat = 32
    var inactiveFontSize: CGFloat = 20
    var activeFontWeight: Font.Weight = .bold
    var alignment: HorizontalAlignment = .leading
    // 接收是否为沉浸模式的状态
    var isImmersive: Bool = true
    
    private var activeLineID: LyricLine.ID? {
        return playerService.lyrics.last(where: {
            $0.startTime <= playerService.currentTime + 0.2
        })?.id
    }
    
    var body: some View {
        VStack {
            if playerService.lyrics.isEmpty {
                Spacer()
                Text("暂无歌词")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            } else {
                // 用 GeometryReader 动态获取高度
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: alignment, spacing: 30) {
                                ForEach(playerService.lyrics) { line in
                                    Text(line.text)
                                        .font(.system(
                                            size: line.id == activeLineID ? activeFontSize : inactiveFontSize,
                                            weight: line.id == activeLineID ? activeFontWeight : .medium
                                        ))
                                        .foregroundColor(line.id == activeLineID ? .white : .white.opacity(0.4))
                                        .multilineTextAlignment(alignment == .leading ? .leading : .center)
                                        .animation(.easeInOut(duration: 0.2), value: activeLineID)
                                        .id(line.id)
                                        .onTapGesture {
                                            playerService.seek(to: line.startTime)
                                        }
                                }
                            }
                            // 动态留白，刚好是视图高度的一半，确保首尾都能完美居中
                            .padding(.vertical, geo.size.height * 0.5)
                            .padding(.horizontal, 20)
                        }
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.15),
                                    .init(color: .black, location: 0.85),
                                    .init(color: .clear, location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        // 首次布局完成后再执行滚动，避免固定延迟带来的竞态
                        .task(id: activeLineID) {
                            guard !playerService.lyrics.isEmpty else { return }
                            await Task.yield()
                            scrollToCurrent(proxy: proxy)
                        }
                    }
                }
            }
        }
    }
    
    // 统一的滚动逻辑
    private func scrollToCurrent(proxy: ScrollViewProxy) {
        let targetID = activeLineID ?? playerService.lyrics.first?.id
        
        if let targetID = targetID {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                let anchorY = isImmersive ? 0.35 : 0.5
                proxy.scrollTo(targetID, anchor: UnitPoint(x: 0.5, y: anchorY))
            }
        }
    }
}
