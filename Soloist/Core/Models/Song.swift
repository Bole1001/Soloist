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
    var url: URL
    var artworkData: Data? // 封面
    
    var lrcURL: URL?       // 外挂歌词路径 (.lrc 文件)
    var embeddedLyrics: String? // ✨ 新增：内嵌歌词文本 (MP3 内部自带的)
    
    // 初始化方法
    init(url: URL,
         title: String? = nil,
         artist: String? = nil,
         artworkData: Data? = nil,
         lrcURL: URL? = nil,
         embeddedLyrics: String? = nil) { // ✨ 参数里加上它
        
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist ?? "Unknown Artist"
        self.artworkData = artworkData
        self.lrcURL = lrcURL
        self.embeddedLyrics = embeddedLyrics
    }
}
