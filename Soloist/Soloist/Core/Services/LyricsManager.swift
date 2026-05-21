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
    
    private var currentSearchToken: UUID = UUID()
    
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
        return lyrics.last(where: { $0.startTime <= time + 0.1 })?.text
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
    func fetchLyrics(for song: Song, duration: TimeInterval, completion: @escaping ([LyricLine], Song?, String?) -> Void) {
        
        let requestToken = UUID()
        self.currentSearchToken = requestToken
        var fallbackErrorMessage: String?
        
        // 策略 A: 检查本地关联的 LRC 文件 (基于 LocalLibrary 扫描时建立的索引)
        if let lrcURL = song.lrcURL {
            switch LRCParser.parse(url: lrcURL) {
            case .success(let parsed):
                if !parsed.isEmpty {
                    completion(parsed, nil, nil)
                    return
                }
            case .failure(let error):
                if case .noLyricsFound = error {
                    break
                } else {
                    fallbackErrorMessage = error.localizedDescription
                }
            }
        }
        
        // 策略 B: 检查音频文件内嵌的歌词
        if let embedded = song.embeddedLyrics, !embedded.isEmpty {
            switch LRCParser.parse(content: embedded) {
            case .success(let parsed):
                if !parsed.isEmpty {
                    completion(parsed, nil, nil)
                    return
                }
            case .failure(let error):
                if case .noLyricsFound = error {
                    break
                } else {
                    fallbackErrorMessage = fallbackErrorMessage ?? error.localizedDescription
                }
            }
        }
        
        // 策略 C: 执行网络搜索
        LyricsFetcher.search(title: song.title, artist: song.artist, album: "", duration: duration) { [weak self] result in
            guard let self = self else { return }
            
            guard self.currentSearchToken == requestToken else {
                print("🛑 [LyricsManager] 拦截到废弃的网络回调，已丢弃 (\(song.title))")
                return
            }
            
            switch result {
            case .success(let content):
                switch LRCParser.parse(content: content) {
                case .success(let parsed):
                    if !parsed.isEmpty {
                        // 下载成功，执行双端统一的落盘逻辑
                        self.saveLrcFile(content: content, for: song) { updatedSong in
                            completion(parsed, updatedSong, nil)
                        }
                    } else {
                        completion([], nil, fallbackErrorMessage ?? LyricsFetchError.noLyricsFound.localizedDescription)
                    }
                case .failure(let error):
                    completion([], nil, fallbackErrorMessage ?? error.localizedDescription)
                }
            case .failure(let error):
                print("⚠️ [LyricsManager] 在线歌词获取失败: \(error.localizedDescription)")
                completion([], nil, fallbackErrorMessage ?? error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Helpers
        
    /// 将歌词内容保存到本地文件系统 (macOS & iOS 逻辑统一)
    private func saveLrcFile(content: String, for song: Song, completion: @escaping (Song) -> Void) {
        let fileManager = FileManager.default
        
        // 构建统一路径： 音频所在目录 / Lyrics / SongName.lrc
        let parentDirectory = song.url.deletingLastPathComponent()
        let lyricsFolderURL = parentDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        let fileName = song.url.deletingPathExtension().lastPathComponent + ".lrc"
        let lrcURL = lyricsFolderURL.appendingPathComponent(fileName)
        
        do {
            // 如果 Lyrics 目录不存在，则级联创建
            if !fileManager.fileExists(atPath: lyricsFolderURL.path) {
                try fileManager.createDirectory(at: lyricsFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 原子化写入文件
            try content.write(to: lrcURL, atomically: true, encoding: .utf8)
            print("💾 [LyricsManager] 歌词已统一落盘至本地: \(lrcURL.path)")
            
            // 生成带有新 LRC 路径的 Song 对象返回
            var updatedSong = song
                updatedSong.lrcURL = lrcURL
                completion(updatedSong)
            
        } catch {
            print("⚠️ [LyricsManager] 歌词落盘失败: \(error)")
            completion(song)
        }
    }
}
