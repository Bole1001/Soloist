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
    var artworkData: Data?
    var lrcURL: URL? // LRC 文件的路径
        
    // 修改初始化方法，增加默认值
    init(url: URL, title: String? = nil, artist: String? = nil, artworkData: Data? = nil, lrcURL: URL? = nil) {
            self.url = url
            // 如果读不到 ID3 title，就兜底使用文件名
            self.title = title ?? url.deletingPathExtension().lastPathComponent
            self.artist = artist ?? "Unknown Artist"
            self.artworkData = artworkData
            self.lrcURL = lrcURL // 赋值
        }
}
