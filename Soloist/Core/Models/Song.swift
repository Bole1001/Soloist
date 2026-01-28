//
//  Song.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation

struct Song: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var artist: String
    var url: URL // 歌曲在硬盘上的物理路径
    
    // 初始化方法
    init(url: URL, title: String, artist: String) {
        self.url = url
        self.title = title
        self.artist = artist
    }
}
