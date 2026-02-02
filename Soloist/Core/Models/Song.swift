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
/// 该模型设计为**轻量级**，仅存储必要的元数据（如路径、标题、艺术家），
/// **不直接存储**封面图片数据（Artwork），以保持极低的内存占用。
///
/// - Note: 封面图片应使用 `ArtworkLoader` 根据 `url` 或 `id` 进行异步按需加载。
struct Song: Identifiable, Hashable, Codable {
    
    // MARK: - Properties
    
    /// 唯一标识符
    ///
    /// 用于在播放列表和 UI 中唯一区分每一首歌曲。
    let id: UUID
    
    /// 音频文件的本地路径
    ///
    /// `AudioEngine` 使用此 URL 进行播放，`MetadataService` 使用此 URL 读取元数据。
    let url: URL
    
    /// 歌曲标题
    ///
    /// 如果元数据中不存在标题，通常会回退使用文件名。
    let title: String
    
    /// 艺术家/歌手名称
    let artist: String
    
    // MARK: - Lyrics Info
    
    /// 关联的外部 LRC 歌词文件路径
    ///
    /// 如果扫描时发现了同名的 .lrc 文件，会存储在此处。
    let lrcURL: URL?
    
    /// 内嵌歌词
    ///
    /// 从 ID3 标签 (USLT/SYLT) 中读取的歌词文本。
    let embeddedLyrics: String?
    
    // MARK: - Codable
    
    /// 编码键映射
    ///
    /// 明确指定参与持久化存储的字段。
    /// 注意：封面数据不参与编码，极大提高了归档和解档的速度。
    enum CodingKeys: String, CodingKey {
        case id, url, title, artist, lrcURL, embeddedLyrics
    }
    
    // MARK: - Initialization
    
    /// 初始化歌曲对象
    ///
    /// - Parameters:
    ///   - id: 唯一标识符，默认为新 UUID。
    ///   - url: 音频文件路径。
    ///   - title: 标题。若为 nil，则自动使用 url 的文件名。
    ///   - artist: 艺术家。若为 nil，则默认为 "Unknown Artist"。
    ///   - lrcURL: 外部歌词路径（可选）。
    ///   - embeddedLyrics: 内嵌歌词内容（可选）。
    init(id: UUID = UUID(),
         url: URL,
         title: String? = nil,
         artist: String? = nil,
         lrcURL: URL? = nil,
         embeddedLyrics: String? = nil) {
        
        self.id = id
        self.url = url
        // 智能回退策略：如果没有标题，就用文件名（去掉 .mp3 后缀）
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist ?? "Unknown Artist"
        self.lrcURL = lrcURL
        self.embeddedLyrics = embeddedLyrics
    }
}
