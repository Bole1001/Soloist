//
//  ArtworkView.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import SwiftUI

// 🔧 适配层：让代码能看懂 Mac 的 NSImage 和 iOS 的 UIImage
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

struct ArtworkView: View {
    let song: Song?
    let size: CGFloat
    
    // 对应你原代码里的 @State private var currentArtwork: Data?
    @State private var currentArtwork: Data? = nil
    
    var body: some View {
        Group {
            // 对应你原代码：if let data = currentArtwork, let nsImage = ...
            if let data = currentArtwork, let image = PlatformImage(data: data) {
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                #endif
            } else {
                // 对应你原代码：占位图逻辑
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            // 稍微调整了图标大小以适应不同 size，逻辑未变
                            .font(.system(size: size * 0.5))
                    )
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(6) // 对应你原代码：.cornerRadius(6)
        .clipped()
        // 对应你原代码：.task(id: playerService.currentSong?.id)
        .task(id: song?.id) {
            if let currentSong = song {
                currentArtwork = await ArtworkLoader.loadArtwork(for: currentSong)
            } else {
                currentArtwork = nil
            }
        }
    }
}
