//
//  LyricLine.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

/// 歌词行模型 (LyricLine)
///
/// 表示歌曲中的单行歌词及其对应的时间戳。
/// 该模型遵循了多个核心协议以支持 SwiftUI 列表渲染、数据排序和持久化存储。
///
/// - Note: 这是一个**不可变模型 (Immutable Model)**，一旦创建，属性不可更改，保证了多线程环境下的安全性。
struct LyricLine: Identifiable, Hashable, Codable, Comparable {
    
    // MARK: - Properties
    
    /// 唯一标识符
    ///
    /// 遵循 `Identifiable` 协议，用于 SwiftUI `ForEach` 循环中高效识别和更新视图。
    /// 使用 UUID 确保每一行歌词在内存中都是独一无二的，防止 UI 渲染时的 ID 冲突。
    let id: UUID
    
    /// 歌词开始时间 (秒)
    ///
    /// 相对于歌曲开始的偏移量。
    /// - Example: `12.5` 表示 00:12.50
    let startTime: TimeInterval
    
    /// 歌词文本内容
    ///
    /// 该行歌词显示的具体文字。
    let text: String
    
    // MARK: - Initialization
    
    /// 创建一个新的歌词行实例
    ///
    /// - Parameters:
    ///   - id: 唯一标识符，默认为自动生成的新 UUID。
    ///   - startTime: 歌词开始的时间点（秒）。
    ///   - text: 歌词的正文内容。
    init(id: UUID = UUID(), startTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.text = text
    }
    
    // MARK: - Comparable
    
    /// 实现 `Comparable` 协议，支持歌词排序
    ///
    /// 允许直接使用 `sort()` 或 `<` 运算符对歌词数组进行排序。
    /// 排序依据是 `startTime`，确保歌词按时间顺序排列。
    ///
    /// - Parameters:
    ///   - lhs: 左侧歌词行
    ///   - rhs: 右侧歌词行
    /// - Returns: 如果左侧歌词的时间早于右侧，则返回 true。
    static func < (lhs: LyricLine, rhs: LyricLine) -> Bool {
        return lhs.startTime < rhs.startTime
    }
}

// MARK: - Debugging

extension LyricLine: CustomStringConvertible {
    
    /// 调试描述信息
    ///
    /// 将歌词对象转换为标准的 LRC 格式字符串，方便在控制台调试和日志记录。
    ///
    /// - Example: `[00:12.50] Hello World`
    var description: String {
        let min = Int(startTime) / 60
        let sec = Double(startTime).truncatingRemainder(dividingBy: 60)
        // 格式说明:
        // %02d   -> 分钟，不足2位补0
        // %05.2f -> 秒数，总宽5位(含小数点)，保留2位小数，不足补0
        // %@     -> 歌词文本
        return String(format: "[%02d:%05.2f] %@", min, sec, text)
    }
}
