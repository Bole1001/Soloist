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
    
    // MARK: - Public API
    
    /// 从文件 URL 解析歌词
    ///
    /// 适用于读取本地 .lrc 文件。
    ///
    /// - Parameter url: 本地文件路径
    /// - Returns: 解析后的歌词数组。如果读取失败（如文件不存在或编码错误），返回空数组。
    static func parse(url: URL) -> [LyricLine] {
        do {
            // 尝试读取文件内容
            // 注意：通常 LRC 文件使用 UTF-8 编码，但也可能是 GBK (需额外处理，这里默认 UTF-8)
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // 复用核心解析逻辑
            return parse(content: content)
        } catch {
            print("⚠️ [LRCParser] 读取文件失败: \(url.lastPathComponent) - \(error)")
            // 失败时返回空数组，避免 UI 崩溃，显示"无歌词"即可
            return []
        }
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
        
        // 2. 准备正则: 匹配 [00:12.34] 格式
        // \\[       -> 匹配左中括号 [
        // (\\d+)    -> 第1组: 分钟 (数字)
        // :         -> 冒号
        // (\\d+\\.?\\d*) -> 第2组: 秒 (整数或小数)
        // \\]       -> 匹配右中括号 ]
        // (.*)      -> 第3组: 歌词文本
        let pattern = "\\[(\\d+):(\\d+\\.?\\d*)\\](.*)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            
            for line in lines {
                // 跳过纯空白行，优化性能
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                
                let nsString = line as NSString
                let results = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first {
                    // 3. 提取正则捕获组
                    // range(at: 1) -> 分钟
                    // range(at: 2) -> 秒
                    // range(at: 3) -> 歌词内容
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                    
                    // 4. 计算时间戳 (转换为秒)
                    if let min = Double(minStr), let sec = Double(secStr) {
                        let time = min * 60 + sec
                        
                        // 创建模型
                        // ID 自动生成，startTime 用于排序，text 用于显示
                        lyrics.append(LyricLine(startTime: time, text: text))
                    }
                }
            }
        } catch {
            print("❌ [LRCParser] 正则表达式错误: \(error)")
        }
        
        // 5. 排序返回
        return lyrics.sorted { $0.startTime < $1.startTime }
    }
}
