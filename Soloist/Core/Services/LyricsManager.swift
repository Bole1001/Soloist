//
//  LyricsManager.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import Foundation

/// 歌词管理器 (LyricsManager)
///
/// **职责**: 协调歌词数据的检索、解析和持久化存储。
/// **层级**: Core Layer (Service)。
///
/// 该类实现了一套标准的歌词加载策略：
/// 1. **本地优先**: 检查是否存在关联的 .lrc 文件。
/// 2. **内嵌兜底**: 检查音频文件的 ID3 标签中是否包含 USLT/SYLT 歌词。
/// 3. **网络补全**: 如果本地无数据，尝试通过 `LyricsFetcher` 在线搜索，下载成功后会自动保存到本地。
class LyricsManager {
    
    // MARK: - Public API
    
    /// 查找当前播放时间对应的歌词行
    ///
    /// - Parameters:
    ///   - lyrics: 已排序的歌词行数组
    ///   - time: 当前播放进度 (秒)
    /// - Returns: 当前应该显示的歌词文本。如果未找到合适的时间点，返回 nil。
    func findCurrentLine(in lyrics: [LyricLine], at time: TimeInterval) -> String? {
        // 查找最后一个开始时间小于或等于当前时间的歌词行
        // 假设 lyrics 数组已经按 startTime 升序排列
        return lyrics.last(where: { $0.startTime <= time })?.text
    }

    /// 异步加载歌词 (核心业务逻辑)
    ///
    /// 按照 本地文件 -> 内嵌元数据 -> 网络搜索 的顺序尝试获取歌词。
    ///
    /// - Parameters:
    ///   - song: 目标歌曲对象
    ///   - duration: 歌曲时长，用于网络搜索时的精确匹配
    ///   - completion: 回调闭包。
    ///     - lyrics: 解析后的歌词行数组。
    ///     - updatedSong: 如果触发了网络下载并保存，会返回更新了 `lrcURL` 的新 Song 对象；否则返回 nil。
    func fetchLyrics(for song: Song, duration: TimeInterval, completion: @escaping ([LyricLine], Song?) -> Void) {
        
        // 策略 A: 检查本地关联的 LRC 文件
        if let lrcURL = song.lrcURL {
            let parsed = LRCParser.parse(url: lrcURL)
            if !parsed.isEmpty {
                completion(parsed, nil)
                return
            }
        }
        
        // 策略 B: 检查音频文件内嵌的歌词
        if let embedded = song.embeddedLyrics, !embedded.isEmpty {
            let parsed = LRCParser.parse(content: embedded)
            if !parsed.isEmpty {
                completion(parsed, nil)
                return
            }
        }
        
        // 策略 C: 执行网络搜索
        LyricsFetcher.search(title: song.title, artist: song.artist, album: "", duration: duration) { [weak self] content in
            guard let self = self, let content = content else {
                // 搜索失败或无网络，返回空结果
                completion([], nil)
                return
            }
            
            let parsed = LRCParser.parse(content: content)
            
            if !parsed.isEmpty {
                // 下载成功，立即写入硬盘持久化，并更新 Song 模型
                self.saveLrcFile(content: content, for: song) { updatedSong in
                    completion(parsed, updatedSong)
                }
            } else {
                completion([], nil)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// 将歌词内容保存到本地文件系统
    ///
    /// 会在音频文件同级目录下创建一个 `Lyrics` 文件夹用于存放。
    ///
    /// - Parameters:
    ///   - content: 歌词全文内容
    ///   - song: 原始歌曲对象
    ///   - completion: 保存成功后，返回带有新 lrcURL 的 Song 对象
    private func saveLrcFile(content: String, for song: Song, completion: @escaping (Song) -> Void) {
        let fileManager = FileManager.default
        
        // 构建路径：./Lyrics/SongName.lrc
        let parentDirectory = song.url.deletingLastPathComponent()
        let lyricsFolderURL = parentDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        let fileName = song.url.deletingPathExtension().lastPathComponent + ".lrc"
        let lrcURL = lyricsFolderURL.appendingPathComponent(fileName)
        
        do {
            // 如果目录不存在，先创建目录
            if !fileManager.fileExists(atPath: lyricsFolderURL.path) {
                try fileManager.createDirectory(at: lyricsFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 写入文件 (原子写入，防止数据损坏)
            try content.write(to: lrcURL, atomically: true, encoding: .utf8)
            
            // 生成新的 Song 实例
            let updatedSong = Song(
                id: song.id,
                url: song.url,
                title: song.title,
                artist: song.artist,
                lrcURL: lrcURL, // 更新歌词路径
                embeddedLyrics: song.embeddedLyrics
            )
            
            completion(updatedSong)
            
        } catch {
            print("⚠️ [LyricsManager] 歌词保存失败: \(error)")
        }
    }
}
