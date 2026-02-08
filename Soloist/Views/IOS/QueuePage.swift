//
//  QueuePage.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import SwiftUI

struct QueuePage: View {
    @EnvironmentObject var playerService: AudioPlayerService
    // 接收从主页传来的封面数据，保持背景一致
    let artworkData: Data?
    
    var body: some View {
        ZStack {
            // 背景
            IOSBackgroundView(artworkData: artworkData)
            
            NavigationStack {
                List {
                    // Section 1: 正在播放
                    if let current = playerService.currentSong {
                        Section(header: Text("正在播放")) {
                            SongListRow(
                                song: current,
                                isPlaying: true,
                                onPlay: { /* 已在播放，点击无效或暂停 */ }
                            )
                        }
                    }
                    
                    // Section 2: 待播清单 (UI 占位)
                    // 这里后续接入 playerService.queue
                    Section(header: Text("即将播放")) {
                        Text("待播列表功能开发中...")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("待播清单")
            }
        }
    }
}
