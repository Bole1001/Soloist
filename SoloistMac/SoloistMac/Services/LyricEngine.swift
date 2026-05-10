//
//  LyricEngine.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import Foundation

struct LyricEngine {
    
    /// 根据 Apple Music 提供的音频路径，加载平级 Lyrics 文件夹下的 .lrc 文件
    /// - Parameter audioPath: 例如 "file:///Users/bole/Music/song.mp3"
    /// - Returns: 解析后的歌词数组
    static func loadLyrics(for audioPath: String) -> [LyricLine] {
        guard let audioURL = URL(string: audioPath) else {
            print("⚠️ [LyricEngine] 无法解析音频路径: \(audioPath)")
            return []
        }
        
        // 核心修正：构建 /Lyrics/同名文件.lrc 的路径
        let parentDirectory = audioURL.deletingLastPathComponent() // 拿到 /Users/bole/Music/
        let lyricsFolderURL = parentDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        let fileName = audioURL.deletingPathExtension().lastPathComponent + ".lrc" // 拿到 song.lrc
        let lrcURL = lyricsFolderURL.appendingPathComponent(fileName) // 组合成最终路径
        
        guard FileManager.default.fileExists(atPath: lrcURL.path) else {
            print("⚠️ [LyricEngine] 未找到本地歌词文件: \(lrcURL.path)")
            return []
        }
        
        print("✅ [LyricEngine] 发现歌词文件，开始解析...")
        return LRCParser.parse(url: lrcURL)
    }
    
    /// 查找当前时间对应的歌词行索引
    /// - Parameters:
    ///   - lyrics: 已解析的歌词数组
    ///   - time: 当前播放时间 (秒)
    /// - Returns: 当前应高亮显示的歌词在数组中的 Index
    static func findCurrentLineIndex(in lyrics: [LyricLine], at time: TimeInterval) -> Int? {
        return lyrics.lastIndex(where: { $0.startTime <= time + 0.1 })
    }
}
