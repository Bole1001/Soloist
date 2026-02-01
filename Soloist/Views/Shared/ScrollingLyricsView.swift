//
//  ScrollingLyricsView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

struct ScrollingLyricsView: View {
    @ObservedObject var playerService: AudioPlayerService
    
    // ✨ 允许外部定制参数，适配 Mac/iPhone 不同屏幕
    var activeFontSize: CGFloat = 32
    var inactiveFontSize: CGFloat = 20
    var activeFontWeight: Font.Weight = .bold
    var alignment: HorizontalAlignment = .leading
    
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
                                    .font(.system(size: isCurrentLine(line) ? activeFontSize : inactiveFontSize,
                                                  weight: isCurrentLine(line) ? activeFontWeight : .medium))
                                    .foregroundColor(isCurrentLine(line) ? .white : .white.opacity(0.4))
                                    .multilineTextAlignment(alignment == .leading ? .leading : .center)
                                    // 动画
                                    .animation(.easeInOut(duration: 0.2), value: playerService.currentLyric)
                                    .id(line.id)
                                    // ✨ 点击歌词跳转进度 (新增功能，可保留可删除)
                                    .onTapGesture {
                                        playerService.seek(to: line.startTime)
                                    }
                            }
                        }
                        // 底部留白，确保最后一句能滚上来
                        .padding(.vertical, 300)
                        .padding(.horizontal, 20)
                    }
                    // 监听当前歌词变化，自动滚动
                    .onChange(of: playerService.currentLyric) {
                        scrollToCurrentLine(proxy: proxy)
                    }
                }
            }
        }
    }
    
    private func isCurrentLine(_ line: LyricLine) -> Bool {
        return playerService.currentLyric == line.text
    }
    
    private func scrollToCurrentLine(proxy: ScrollViewProxy) {
        if let currentLine = playerService.lyrics.first(where: { $0.text == playerService.currentLyric }) {
            withAnimation {
                proxy.scrollTo(currentLine.id, anchor: .center)
            }
        }
    }
}
