//
//  LyricLine.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

struct LyricLine: Identifiable, Hashable, Codable, Comparable {
    // 模型数据生成后不可变，使用 let 保证安全性
    let id: UUID
    let startTime: TimeInterval
    let text: String
    
    // 自定义初始化，支持 UUID 自动生成
    init(id: UUID = UUID(), startTime: TimeInterval, text: String) {
        self.id = id
        self.startTime = startTime
        self.text = text
    }
    
    // 实现 Comparable 协议，支持直接按时间排序
    static func < (lhs: LyricLine, rhs: LyricLine) -> Bool {
        return lhs.startTime < rhs.startTime
    }
}

// 调试扩展：优化打印输出格式（如 [00:12.50] 歌词内容）
extension LyricLine: CustomStringConvertible {
    var description: String {
        let min = Int(startTime) / 60
        let sec = Double(startTime).truncatingRemainder(dividingBy: 60)
        return String(format: "[%02d:%05.2f] %@", min, sec, text)
    }
}
