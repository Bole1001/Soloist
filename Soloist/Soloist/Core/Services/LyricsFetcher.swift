//
//  LyricsFetcher.swift
//  Soloist
//
//  Created by Bole on 2026/1/30.
//

import Foundation

/// LRCLIB 接口返回的歌曲数据模型
struct LRCLibSong: Codable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String
    
    /// 歌曲时长 (秒)
    let duration: Double
    
    /// 带时间轴的歌词 (LRC格式)
    let syncedLyrics: String?
    
    /// 纯文本歌词
    let plainLyrics: String?
}

/// 负责从网络获取歌词的工具类
class LyricsFetcher {
    
    /// 根据歌名、歌手和时长搜索歌词
    ///
    /// - Parameters:
    ///   - title: 歌曲标题
    ///   - artist: 歌手名称
    ///   - album: 专辑名称
    ///   - duration: 歌曲时长（秒），用于辅助筛选最佳匹配结果
    ///   - completion: 搜索结果回调。成功返回歌词内容字符串，失败返回 nil
    static func search(title: String, artist: String, album: String, duration: TimeInterval, completion: @escaping (String?) -> Void) {
        
        // 构建 API 请求 URL
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        
        // 使用指定字段进行精确查询，提高匹配准确度
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        
        guard let url = components.url else {
            print("[LyricsFetcher] URL 构建失败")
            completion(nil)
            return
        }
        
        // 配置请求头，设置 User-Agent 以符合 API 调用规范
        var request = URLRequest(url: url)
        request.setValue("SoloistApp/1.0 (iOS; SwiftUI)", forHTTPHeaderField: "User-Agent")
        
        print("[LyricsFetcher] 开始搜索: \(title) - \(artist)")
        
        // 发起异步网络请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("[LyricsFetcher] 网络请求错误: \(error?.localizedDescription ?? "未知错误")")
                completion(nil)
                return
            }
            
            do {
                // 解析 JSON 数据
                let results = try JSONDecoder().decode([LRCLibSong].self, from: data)
                
                if results.isEmpty {
                    completion(nil)
                    return
                }
                
                var bestMatch: LRCLibSong?
                
                // 如果提供了时长，优先筛选时长误差在 3 秒以内的结果
                if duration > 0 {
                    bestMatch = results.first { song in
                        return abs(song.duration - duration) < 3.0
                    }
                }
                
                // 如果没有找到时长匹配的项目，默认使用第一个搜索结果
                let finalPick = bestMatch ?? results.first
                
                if let song = finalPick {
                    // 优先返回带时间轴的歌词，如果不存在则返回纯文本歌词
                    let lyricsContent = song.syncedLyrics ?? song.plainLyrics
                    
                    if let content = lyricsContent, !content.isEmpty {
                        print("[LyricsFetcher] 歌词下载成功: \(song.trackName)")
                        completion(content)
                    } else {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
                
            } catch {
                print("[LyricsFetcher] 数据解析失败: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
}
