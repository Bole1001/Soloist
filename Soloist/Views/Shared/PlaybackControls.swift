//
//  PlaybackControls.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

struct BouncyPlaybackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 播放控制组件 (PlaybackControls)
struct PlaybackControls: View {
    
    @ObservedObject var playerService: AudioPlayerService
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    
    let size: CGFloat
    var onQueueTap: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            // MARK: - 1. 红心 (左一)
            Group {
                if let currentSong = playerService.currentSong {
                    let isFav = userPlaylistManager.isFavorite(songID: currentSong.id)
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            userPlaylistManager.toggleFavorite(songID: currentSong.id)
                        }
                    } label: {
                        Image(systemName: isFav ? "heart.fill" : "heart")
                            .font(.system(size: size * 0.6, weight: .medium))
                            .foregroundStyle(isFav ? Color.red : Color.white.opacity(0.6))
                            .scaleEffect(isFav ? 1.1 : 1.0)
                            .frame(width: size, height: size)
                    }
                    .buttonStyle(BouncyPlaybackButtonStyle())
                } else {
                    Color.clear.frame(width: size, height: size)
                }
            }
            
            Spacer()
            
            // MARK: - 2. 上一首 (左二 - 视觉降重)
            Button(action: {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                playerService.previous()
            }) {
                Image(systemName: "backward.fill")
                    // ✨ 核心修复：限制字重为 regular，防止变通体肥胖
                    .font(.system(size: size * 0.7, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: size, height: size)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            
            Spacer()
            
            // MARK: - 3. 播放/暂停
            Button(action: {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                playerService.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 1.8, height: size * 1.8)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    
                    Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: size * 0.8, weight: .black))
                        .foregroundColor(.black)
                        .contentTransition(.symbolEffect(.replace))
                        .offset(x: playerService.isPlaying ? 0 : size * 0.08)
                }
                .frame(width: size * 1.8, height: size * 1.8)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            
            Spacer()
            
            // MARK: - 4. 下一首 (右二 - 视觉降重)
            Button(action: {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                playerService.next()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: size * 0.7, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: size, height: size)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            
            Spacer()
            
            // MARK: - 5. 播放列表 (右一)
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onQueueTap?()
            } label: {
                Image(systemName: "music.note.list")
                    .font(.system(size: size * 0.6, weight: .medium))
                    .foregroundStyle(onQueueTap == nil ? Color.secondary.opacity(0.5) : Color.white.opacity(0.6))
                    .frame(width: size, height: size)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            .disabled(onQueueTap == nil)
        }
        .frame(maxWidth: 340) // 稍微放宽一点，让大按钮有呼吸空间
    }
}
