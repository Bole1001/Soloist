//
//  LRCParser.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

struct LRCParser {
    
    // 传入 LRC 文件的路径，返回解析好的歌词数组
    static func parse(url: URL) -> [LyricLine] {
        var lyrics: [LyricLine] = []
        
        do {
            // 1. 读取文件内容
            // 注意：很多老歌词文件是 GBK 编码，这里先尝试 UTF-8
            // 如果你有很多乱码歌词，这里需要做更复杂的编码探测
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // 2. 按行切割
            let lines = content.components(separatedBy: .newlines)
            
            // 3. 正则表达式：匹配 [00:12.34] 这种格式
            // 解释：\[(\d+) 分钟 : (\d+\.?\d*) 秒 \] (歌词内容)
            let pattern = "\\[(\\d+):(\\d+\\.?\\d*)\\](.*)"
            let regex = try NSRegularExpression(pattern: pattern)
            
            for line in lines {
                // 跳过空行
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                
                let nsString = line as NSString
                let results = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first {
                    // 提取分钟
                    let minRange = match.range(at: 1)
                    let minStr = nsString.substring(with: minRange)
                    
                    // 提取秒
                    let secRange = match.range(at: 2)
                    let secStr = nsString.substring(with: secRange)
                    
                    // 提取歌词文本
                    let textRange = match.range(at: 3)
                    let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespaces)
                    
                    // 计算总秒数
                    if let min = Double(minStr), let sec = Double(secStr) {
                        let time = min * 60 + sec
                        let lyricLine = LyricLine(startTime: time, text: text)
                        lyrics.append(lyricLine)
                    }
                }
            }
            
        } catch {
            // 如果找不到文件或解析失败，就静默失败，返回空数组
            // print("LRC 解析失败: \(error)")
        }
        
        // 4. 确保按时间排序
        return lyrics.sorted { $0.startTime < $1.startTime }
    }
}
