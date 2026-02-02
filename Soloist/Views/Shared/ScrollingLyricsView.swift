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
    
    // MARK: - Dependencies
    @ObservedObject var playerService: AudioPlayerService
    
    // MARK: - Configuration
    var activeFontSize: CGFloat = 32
    var inactiveFontSize: CGFloat = 20
    var activeFontWeight: Font.Weight = .bold
    var alignment: HorizontalAlignment = .leading
    
    // ✨ 1. 计算属性：根据当前时间找到正在播放的那一行 ID
    // 这比对比文本 (String) 更准确，能区分内容相同的重复歌词
    private var activeLineID: LyricLine.ID? {
        // 找到最后一句“起始时间 <= 当前时间”的歌词
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
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: alignment, spacing: 30) {
                            ForEach(playerService.lyrics) { line in
                                Text(line.text)
                                    // ✨ 2. 修改：使用 ID 对比来判断高亮
                                    .font(.system(size: line.id == activeLineID ? activeFontSize : inactiveFontSize,
                                                  weight: line.id == activeLineID ? activeFontWeight : .medium))
                                    .foregroundColor(line.id == activeLineID ? .white : .white.opacity(0.4))
                                    .multilineTextAlignment(alignment == .leading ? .leading : .center)
                                    // 动画：当 ID 变化时才有动画
                                    .animation(.easeInOut(duration: 0.2), value: activeLineID)
                                    .id(line.id)
                                    .onTapGesture {
                                        playerService.seek(to: line.startTime)
                                    }
                            }
                        }
                        .padding(.vertical, 300) // 保持原有留白
                        .padding(.horizontal, 20)
                    }
                    // ✨ 3. 视觉优化：添加渐变遮罩 (Mask)
                    // 让歌词在顶部和底部呈现“淡入淡出”效果，而不是生硬消失
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),    // 顶部透明
                                .init(color: .black, location: 0.15), // 中间显示
                                .init(color: .black, location: 0.85), // 中间显示
                                .init(color: .clear, location: 1)     // 底部透明
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // ✨ 4. 修改：监听 activeLineID 变化来驱动滚动
                    .onChange(of: activeLineID) {
                        if let targetID = activeLineID {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                proxy.scrollTo(targetID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}
