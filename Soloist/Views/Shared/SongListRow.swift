//
//  SongListRow.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// MARK: - Platform Adaptation
#if os(macOS)
import AppKit
typealias SongRowImage = NSImage
#else
import UIKit
typealias SongRowImage = UIImage
#endif

struct SongListRow: View {
    // MARK: - Parameters
    let song: Song
    let isPlaying: Bool
    let onPlay: () -> Void
    let onAdd: () -> Void
    
    // 依赖注入
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    
    // MARK: - Local State
    @State private var rowArtwork: Data? = nil
    
    #if os(macOS)
    @State private var isHovering: Bool = false
    #endif
    
    // 辅助计算属性 1
    private var shouldShowOverlay: Bool {
        #if os(macOS)
        return isPlaying || isHovering
        #else
        return isPlaying
        #endif
    }
    
    // ✨ 修复 1：将其移出 body，作为结构体的独立成员
    private var isHoveringForStyle: Bool {
        #if os(macOS)
        return isHovering
        #else
        return false
        #endif
    }
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                
                // MARK: - 1. Artwork Section
                ZStack {
                    if let data = rowArtwork, let image = SongRowImage(data: data) {
                        #if os(macOS)
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                        #else
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        #endif
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                    }
                    
                    if shouldShowOverlay {
                        Color.black.opacity(0.4)
                            .transition(.opacity)
                        
                        #if os(macOS)
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        #else
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        #endif
                    }
                }
                .frame(width: 48, height: 48)
                .cornerRadius(8)
                .task(id: song.id) {
                    if rowArtwork == nil {
                        rowArtwork = await ArtworkLoader.loadArtwork(for: song)
                    }
                }
                
                // MARK: - 2. Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isPlaying ? .blue : .primary)
                        .lineLimit(1)
                    
                    Text(song.artist)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // MARK: - 3. Add to Playlist Menu
                Menu {
                    if userPlaylistManager.customPlaylists.isEmpty {
                        Text("暂无自建歌单")
                    } else {
                        Text("添加到歌单")
                        ForEach(userPlaylistManager.customPlaylists) { playlist in
                            let isAlreadyIn = playlist.songIDs.contains(song.id)
                            Button(action: {
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                #endif
                                userPlaylistManager.addSong(song.id, toPlaylist: playlist.id)
                            }) {
                                Label(playlist.name, systemImage: isAlreadyIn ? "checkmark.circle.fill" : "music.note.list")
                            }
                            .disabled(isAlreadyIn)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, -5)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        } // ✨ 修复 2：Button 实体必须在这里完全闭合
        
        // ✨ 修复 3：修饰符必须挂载在 Button 的外部层级
        .buttonStyle(SongRowButtonStyle(isPlaying: isPlaying, isHovering: isHoveringForStyle))
        
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
        #endif // ✨ 修复 4：修正了非法的 #endif 语法
    }
}

// MARK: - Custom Button Style
struct SongRowButtonStyle: ButtonStyle {
    let isPlaying: Bool
    let isHovering: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if isPlaying {
            return Color.accentColor.opacity(0.1)
        }
        if isPressed {
            return Color.gray.opacity(0.2)
        }
        if isHovering {
            return Color.gray.opacity(0.1)
        }
        return Color.clear
    }
}
