//
//  Song.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation

/// 歌曲核心模型 (Song)
///
/// 表示一首独立的音频曲目。
/// 该模型设计为**轻量级**，仅存储必要的元数据，不包含封面。
struct Song: Identifiable, Hashable, Codable, Sendable {
    
    /// 唯一标识符
    let id: String
    
    var url: URL
    
    /// 歌曲标题
    let title: String
    
    /// 艺术家/歌手名称
    let artist: String
    
    var lrcURL: URL?
    
    let embeddedLyrics: String?
}
