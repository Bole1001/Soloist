//
//  LyricsFetcher.swift
//  Soloist
//
//  Created by Bole on 2026/1/30.
//

import Foundation

// 定义 LRCLIB 返回的数据格式
struct LRCLibSong: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String
    let duration: Double
    let syncedLyrics: String?  // 带时间轴的歌词
    let plainLyrics: String?   // 纯文本歌词
}

class LyricsFetcher {
    
    // 🔍 搜索歌词的主函数
    // duration: 传入歌曲时长（秒），可以提高匹配准确度。如果不确定填 0。
    static func search(title: String, artist: String, album: String, duration: TimeInterval, completion: @escaping (String?) -> Void) {
        
        // 1. 准备搜索参数
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        
        // 组合查询关键字 "歌手 歌名"
        let query = "\(artist) \(title)"
        
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        
        guard let url = components.url else {
            print("❌ URL 构建失败")
            completion(nil)
            return
        }
        
        print("🌐 [LyricsFetcher] 正在联网搜索: \(query)...")
        
        // 2. 发起请求
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ [LyricsFetcher] 网络请求出错: \(error?.localizedDescription ?? "未知错误")")
                completion(nil)
                return
            }
            
            do {
                // 3. 解析结果
                let results = try JSONDecoder().decode([LRCLibSong].self, from: data)
                
                if results.isEmpty {
                    print("⚠️ [LyricsFetcher] 未找到任何歌词")
                    completion(nil)
                    return
                }
                
                // 4. 智能筛选：找一个时长最接近的 (误差 3 秒内)
                var bestMatch: LRCLibSong?
                
                if duration > 0 {
                    bestMatch = results.first { song in
                        return abs(song.duration - duration) < 3.0
                    }
                }
                
                // 如果没找到时长匹配的，就默认拿第一个
                let finalPick = bestMatch ?? results.first
                
                if let song = finalPick {
                    // 优先返回带时间轴的，没有则返回纯文本
                    let lyrics = song.syncedLyrics ?? song.plainLyrics
                    print("✅ [LyricsFetcher] 成功下载歌词: \(song.trackName)")
                    completion(lyrics)
                } else {
                    completion(nil)
                }
                
            } catch {
                print("❌ [LyricsFetcher] JSON 解析失败: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
}
