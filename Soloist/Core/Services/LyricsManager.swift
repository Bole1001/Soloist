//
//  LyricsManager.swift
//  Soloist
//
//  Created by Bole on 2026/2/1.
//

import Foundation

class LyricsManager {
    // 逻辑：寻找当前时间点对应的歌词行
    func findCurrentLine(in lyrics: [LyricLine], at time: TimeInterval) -> String? {
        return lyrics.last(where: { $0.startTime <= time })?.text
    }

    // 主逻辑：寻找歌词
    func fetchLyrics(for song: Song, duration: TimeInterval, completion: @escaping ([LyricLine], Song?) -> Void) {
        // 1. 本地策略
        if let lrcURL = song.lrcURL {
            let parsed = LRCParser.parse(url: lrcURL)
            if !parsed.isEmpty {
                completion(parsed, nil)
                return
            }
        }
        
        // 2. 内嵌策略
        if let embedded = song.embeddedLyrics, !embedded.isEmpty {
            let parsed = LRCParser.parse(content: embedded)
            if !parsed.isEmpty {
                completion(parsed, nil)
                return
            }
        }
        
        // 3. 联网策略
        LyricsFetcher.search(title: song.title, artist: song.artist, album: "", duration: duration) { [weak self] content in
            guard let self = self, let content = content else {
                completion([], nil)
                return
            }
            
            let parsed = LRCParser.parse(content: content)
            if !parsed.isEmpty {
                // 下载成功，执行保存并获取更新后的 Song
                self.saveLrcFile(content: content, for: song) { updatedSong in
                    completion(parsed, updatedSong)
                }
            } else {
                completion([], nil)
            }
        }
    }
    
    // 文件操作：写硬盘并生成新的 Song 对象
    private func saveLrcFile(content: String, for song: Song, completion: @escaping (Song) -> Void) {
        let fileManager = FileManager.default
        let parentDirectory = song.url.deletingLastPathComponent()
        let lyricsFolderURL = parentDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        let fileName = song.url.deletingPathExtension().lastPathComponent + ".lrc"
        let lrcURL = lyricsFolderURL.appendingPathComponent(fileName)
        
        do {
            if !fileManager.fileExists(atPath: lyricsFolderURL.path) {
                try fileManager.createDirectory(at: lyricsFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
            try content.write(to: lrcURL, atomically: true, encoding: .utf8)
            
            let updatedSong = Song(
                id: song.id,
                url: song.url,
                title: song.title,
                artist: song.artist,
                lrcURL: lrcURL,
                embeddedLyrics: song.embeddedLyrics
            )
            completion(updatedSong)
        } catch {
            print("⚠️ 歌词保存失败: \(error)")
        }
    }
}
