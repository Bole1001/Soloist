//
//  LibraryPersistenceService.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation

class LibraryPersistenceService {
    
    // 1. 决定账本存哪里
    // 通常存在用户的 "Application Support/Soloist" 文件夹下
    private static var libraryFileURL: URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // 确保文件夹存在 (第一次运行时需要创建)
        let appDir = appSupport.appendingPathComponent("Soloist")
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        
        return appDir.appendingPathComponent("library.json")
    }
    
    // 2. 保存 (记账)
    static func saveLibrary(songs: [Song]) {
        guard let url = libraryFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            // outputFormatting = .prettyPrinted // 如果你想看生成的 JSON 长啥样，可以打开这个，但文件会变大
            let data = try encoder.encode(songs)
            try data.write(to: url)
            print("💾 [Persistence] 成功保存 \(songs.count) 首歌到本地数据库")
        } catch {
            print("❌ [Persistence] 保存失败: \(error)")
        }
    }
    
    // 3. 读取 (查账)
    static func loadLibrary() -> [Song] {
        guard let url = libraryFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ [Persistence] 本地数据库不存在，准备从头扫描...")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let songs = try decoder.decode([Song].self, from: data)
            print("📂 [Persistence] 成功从本地数据库加载 \(songs.count) 首歌")
            return songs
        } catch {
            print("❌ [Persistence] 加载失败 (可能是数据结构变了): \(error)")
            return []
        }
    }
}
