//
//  Song.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation

struct Song: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    // ❌ let artworkData: Data?  <-- 彻底删掉这行
    
    let lrcURL: URL?
    let embeddedLyrics: String?
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, artist, lrcURL, embeddedLyrics
    }
    
    // 初始化方法也简化了
    init(id: UUID = UUID(),
         url: URL,
         title: String? = nil,
         artist: String? = nil,
         // artworkData 参数删掉
         lrcURL: URL? = nil,
         embeddedLyrics: String? = nil) {
        
        self.id = id
        self.url = url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist ?? "Unknown Artist"
        // self.artworkData 赋值删掉
        self.lrcURL = lrcURL
        self.embeddedLyrics = embeddedLyrics
    }
}
