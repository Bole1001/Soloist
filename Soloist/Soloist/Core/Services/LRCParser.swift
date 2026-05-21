//
//  LRCParser.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

/// LRC 歌词解析器 (LRCParser)
///
/// **职责**: 负责将标准 LRC 格式的字符串解析为结构化的 `LyricLine` 数组。
/// **层级**: Core Layer (Utility).
///
/// 支持标准的 `[mm:ss.xx]` 时间戳格式。
/// 解析结果会自动按时间升序排列，确保播放器能按顺序读取。
struct LRCParser {
    
    // 预编译时间标签正则，避免每次解析重复构造；构造失败时直接走空结果降级。
    private static let timeTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\[(\\d+):(\\d+\\.?\\d*)\\]")
    }()
    
    // MARK: - Public API
    
    /// 从文件 URL 解析歌词
    ///
    /// 适用于读取本地 .lrc 文件。
    ///
    /// - Parameter url: 本地文件路径
    /// - Returns: 解析后的歌词数组。如果读取失败（如文件不存在或编码错误），返回空数组。
    static func parse(url: URL) -> [LyricLine] {
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return parse(content: content)
        }
        
        let gb18030Encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let content = try? String(contentsOf: url, encoding: gb18030Encoding) {
            return parse(content: content)
        }
        
        print("⚠️ [LRCParser] 读取文件失败或编码无法识别: \(url.lastPathComponent)")
        return []
    }
    
    /// 从原始字符串解析歌词 (核心逻辑)
    ///
    /// 适用于解析 MP3 内嵌歌词 (ID3 USLT/SYLT) 或网络下载的字符串。
    ///
    /// - Parameter content: LRC 格式的全文内容
    /// - Returns: 按时间排序的歌词数组
    static func parse(content: String) -> [LyricLine] {
        var lyrics: [LyricLine] = []
        
        // 1. 按行切割，处理不同系统的换行符 (\n, \r\n)
        let lines = content.components(separatedBy: .newlines)

        guard let regex = timeTagRegex else {
            return []
        }
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            let nsString = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
            guard !matches.isEmpty, let lastMatch = matches.last else { continue }
            
            // 文本内容位于最后一个时间戳之后，元数据行会因为没有歌词文本而自然降级为空串。
            let textStartLocation = lastMatch.range.location + lastMatch.range.length
            let text = nsString.substring(from: textStartLocation).trimmingCharacters(in: .whitespaces)
            
            for match in matches {
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))
                
                guard let min = Double(minStr), let sec = Double(secStr) else { continue }
                let time = min * 60 + sec
                
                lyrics.append(LyricLine(startTime: time, text: text))
            }
        }
        
        // 5. 排序返回
        return lyrics.sorted { $0.startTime < $1.startTime }
    }
}
