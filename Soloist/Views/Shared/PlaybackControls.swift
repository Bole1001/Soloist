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
                            .font(.system(size: size * 0.55))
                            .foregroundStyle(isFav ? Color.red : Color.white.opacity(0.8))
                            .scaleEffect(isFav ? 1.1 : 1.0)
                            .frame(width: size, height: size)
                    }
                    .buttonStyle(BouncyPlaybackButtonStyle())
                } else {
                    Color.clear.frame(width: size, height: size)
                }
            }
            
            Spacer()
            
            // MARK: - 2. 上一首 (左二)
            Button(action: {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                playerService.previous()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: size * 0.65))
                    .frame(width: size, height: size)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            
            Spacer()
            
            // MARK: - 3. 播放/暂停 (绝对居中)
            Button(action: {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                playerService.togglePlayPause()
            }) {
                Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: size * 1.3))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: size * 1.5, height: size * 1.5)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            
            Spacer()
            
            // MARK: - 4. 下一首 (右二)
            Button(action: {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                playerService.next()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: size * 0.65))
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
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(onQueueTap == nil ? Color.secondary.opacity(0.5) : Color.white.opacity(0.8))
                    .frame(width: size, height: size)
            }
            .buttonStyle(BouncyPlaybackButtonStyle())
            .disabled(onQueueTap == nil)
        }
        .frame(maxWidth: 320)
    }
}
