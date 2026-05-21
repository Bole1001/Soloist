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
    
    // 将正则表达式提取为静态变量，避免重复编译损耗性能；编译失败时直接降级为空结果。
    private static let timeTagRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: "\\[(\\d+):(\\d+\\.?\\d*)\\]")
    }()
    
    static func parse(url: URL) -> [LyricLine] {
        // 1. 优先尝试 UTF-8 编码读取
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return parse(content: content)
        }
        
        // 2. 回退机制：尝试 GB18030 (兼容 GBK/GB2312) 编码读取
        let gbkEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        if let content = try? String(contentsOf: url, encoding: gbkEncoding) {
            return parse(content: content)
        }
        
        print("⚠️ [LRCParser] 读取文件失败或编码无法识别: \(url.lastPathComponent)")
        return []
    }
    
    static func parse(content: String) -> [LyricLine] {
        var lyrics: [LyricLine] = []
        let lines = content.components(separatedBy: .newlines)
        
        guard let regex = timeTagRegex else { return [] }
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            
            let nsString = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
            
            // 跳过不含时间戳的元数据行 (如 [ti:标题])
            guard !matches.isEmpty, let lastMatch = matches.last else { continue }
            
            // 文本内容位于该行最后一个时间戳之后
            let textStartLocation = lastMatch.range.location + lastMatch.range.length
            let text = nsString.substring(from: textStartLocation).trimmingCharacters(in: .whitespaces)
            
            // 遍历该行提取到的所有时间戳，将同一个文本与不同的时间戳分别关联存储
            for match in matches {
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))
                
                guard let min = Double(minStr), let sec = Double(secStr) else { continue }
                let time = min * 60 + sec
                lyrics.append(LyricLine(startTime: time, text: text))
            }
        }
        return lyrics.sorted()
    }
}
