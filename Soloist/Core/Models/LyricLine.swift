//
//  LyricLine.swift
//  Soloist
//
//  Created by Bole on 2026/1/29.
//

import Foundation

struct LyricLine: Identifiable, Hashable {
    var id = UUID()
    var startTime: TimeInterval // 这句歌词开始的时间（秒）
    var text: String            // 歌词内容
}
