//
//  PlaybackControls.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

/// 播放控制组件 (PlaybackControls)
///
/// **职责**: 提供上一首、播放/暂停、下一首这三个核心控制按钮。
/// **特性**:
/// 1. 样式高度复用：支持通过 `size` 参数整体缩放。
/// 2. 视觉层级：播放/暂停按钮比两侧按钮大一倍 (1.2x vs 0.6x)，突出核心操作。
/// 3. 交互优化：播放状态切换时具备丝滑的符号过渡动画。
struct PlaybackControls: View {
    
    // MARK: - Dependencies
    @ObservedObject var playerService: AudioPlayerService
    
    /// 基础尺寸基准
    ///
    /// 所有按钮的大小和间距都基于此数值进行比例缩放，以保持布局比例一致。
    let size: CGFloat
    
    var body: some View {
        // 使用动态间距：约为基础尺寸的 60%
        HStack(spacing: size * 0.6) {
            
            // MARK: - Previous Track
            Button(action: { playerService.previous() }) {
                Image(systemName: "backward.fill")
                    // 辅助按钮大小：基础尺寸的 60%
                    .font(.system(size: size * 0.6))
            }
            .buttonStyle(.plain)
            
            // MARK: - Play / Pause
            Button(action: { playerService.togglePlayPause() }) {
                // 根据播放状态切换实心圆图标
                Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    // 核心按钮大小：基础尺寸的 120%
                    .font(.system(size: size * 1.2))
                    // ✨ 核心修改：添加符号替换的过渡动画
                    // 当图标从 play 变为 pause 时，会有形变过渡效果 (需 macOS 14+ / iOS 17+)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            
            // MARK: - Next Track
            Button(action: { playerService.next() }) {
                Image(systemName: "forward.fill")
                    // 辅助按钮大小：基础尺寸的 60%
                    .font(.system(size: size * 0.6))
            }
            .buttonStyle(.plain)
        }
    }
}
