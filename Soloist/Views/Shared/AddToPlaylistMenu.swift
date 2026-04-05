//
//  AddToPlaylistMenu.swift
//  Soloist
//
//  Created by Bole on 2026/4/5.
//

import SwiftUI

/// 高度解耦的“添加到歌单”菜单组件
/// 使用泛型 Label 允许调用方自定义按钮长相 (加号、三个点等)
struct AddToPlaylistMenu<LabelContent: View>: View {
    let song: Song
    let label: LabelContent
    
    @EnvironmentObject var userPlaylistManager: UserPlaylistManager
    
    init(song: Song, @ViewBuilder label: () -> LabelContent) {
        self.song = song
        self.label = label()
    }
    
    var body: some View {
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
            label
        }
    }
}
