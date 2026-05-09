//
//  SongListRow.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI
import UIKit

typealias SongRowImage = UIImage

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
    
    // 辅助计算属性 1
    private var shouldShowOverlay: Bool {
        return isPlaying
    }
    
    private var isHoveringForStyle: Bool {
        return false
    }
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                
                // MARK: - 1. Artwork Section
                ZStack {
                    if let data = rowArtwork, let image = SongRowImage(data: data) {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .overlay(Image(systemName: "music.note").foregroundColor(.secondary))
                    }
                    
                    if shouldShowOverlay {
                        Color.black.opacity(0.4)
                            .transition(.opacity)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
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
                AddToPlaylistMenu(song: song) {
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
        }
        
        .buttonStyle(SongRowButtonStyle(isPlaying: isPlaying))
    }
}

// MARK: - Custom Button Style
struct SongRowButtonStyle: ButtonStyle {
    let isPlaying: Bool
    
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
        return Color.clear
    }
}
