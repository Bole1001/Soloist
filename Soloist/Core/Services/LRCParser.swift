//
//  LRCParser.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

struct LRCParser {
    
    // 入口 1: 传入文件 URL (给 .lrc 文件用)
    static func parse(url: URL) -> [LyricLine] {
        do {
            // 尝试读取文件内容
            let content = try String(contentsOf: url, encoding: .utf8)
            // 调用下面的核心解析逻辑
            return parse(content: content)
        } catch {
            // 如果读取失败(比如编码不对)，返回空
            return []
        }
    }
    
    // ✨ 入口 2: 直接传入字符串 (给 MP3 内嵌歌词用)
    static func parse(content: String) -> [LyricLine] {
        var lyrics: [LyricLine] = []
        
        // 1. 按行切割
        let lines = content.components(separatedBy: .newlines)
        
        // 2. 准备正则: [00:12.34]
        let pattern = "\\[(\\d+):(\\d+\\.?\\d*)\\](.*)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            
            for line in lines {
                // 跳过空行
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                
                let nsString = line as NSString
                let results = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first {
                    // 提取分、秒、文本
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                    
                    if let min = Double(minStr), let sec = Double(secStr) {
                        let time = min * 60 + sec
                        lyrics.append(LyricLine(startTime: time, text: text))
                    }
                }
            }
        } catch {
            print("LRC 正则错误: \(error)")
        }
        
        return lyrics.sorted { $0.startTime < $1.startTime }
    }
}
