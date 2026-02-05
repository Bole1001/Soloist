//
//  LibraryPersistenceService.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation

/// 图书馆持久化服务 (LibraryPersistenceService)
///
/// **职责**: 负责将内存中的歌曲列表 (`[Song]`) 序列化并保存到硬盘，以及从硬盘读取恢复。
/// **层级**: Core Layer (数据持久层)。
/// **机制**: 使用 Swift 原生的 `Codable` 协议配合 `JSONEncoder/Decoder`。
///
/// - Note: 数据存储在用户的 `Application Support` 目录中，这是 macOS/iOS 推荐存放 App 内部数据的标准位置，不会干扰用户的文档目录。
class LibraryPersistenceService {
    
    // MARK: - File Path Logic
    
    /// 数据库文件的存储位置
    ///
    /// 通常位于: `~/Library/Application Support/Soloist/library.json`
    ///
    /// - Returns: 指向 JSON 文件的 URL。如果无法访问沙盒目录，返回 nil。
    private static var libraryFileURL: URL? {
        let fileManager = FileManager.default
        
        // 1. 获取系统标准的 Application Support 目录
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // 2. 拼接 App 专属子文件夹
        let appDir = appSupport.appendingPathComponent("Soloist")
        
        // 3. 懒加载创建目录 (Lazy Creation)
        // 如果文件夹不存在，则尝试创建它。
        if !fileManager.fileExists(atPath: appDir.path) {
            do {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                print("❌ [Persistence] 无法创建应用数据目录: \(error)")
                return nil
            }
        }
        
        // 4. 返回完整的文件路径
        return appDir.appendingPathComponent("library.json")
    }
    
    // MARK: - Save (Write)
    
    /// 保存歌曲列表到硬盘 (记账)
    ///
    /// 将 `[Song]` 数组编码为 JSON 数据并写入文件。
    ///
    /// - Parameter songs: 需要保存的歌曲数组。
    static func saveLibrary(songs: [Song]) {
        guard let url = libraryFileURL else { return }
        
        do {
            let encoder = JSONEncoder()
            // 提示：调试时可以开启 .prettyPrinted，但在生产环境关闭以减小文件体积
            // encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(songs)
            
            // 使用 .atomic 写入
            try data.write(to: url, options: .atomic)
            
            print("💾 [Persistence] 成功保存 \(songs.count) 首歌到本地数据库")
        } catch {
            print("❌ [Persistence] 保存失败: \(error)")
        }
    }
    
    // MARK: - Load (Read)
    
    /// 从硬盘加载歌曲列表 
    ///
    /// App 启动时调用此方法恢复上次的状态。
    ///
    /// - Returns: 解析成功的歌曲数组。如果文件不存在或解析失败，返回空数组。
    static func loadLibrary() -> [Song] {
        guard let url = libraryFileURL else { return [] }
        
        // 1. 检查文件是否存在
        if !FileManager.default.fileExists(atPath: url.path) {
            print("⚠️ [Persistence] 本地数据库不存在，准备初始化为空库...")
            return []
        }
        
        // 2. 尝试读取并解码
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let songs = try decoder.decode([Song].self, from: data)
            
            print("📂 [Persistence] 成功从本地数据库加载 \(songs.count) 首歌")
            return songs
        } catch {
            // 通常发生在 Song 模型结构发生巨大变化，导致旧 JSON 无法解析时
            print("❌ [Persistence] 加载失败 (数据可能已损坏或版本不兼容): \(error)")
            return []
        }
    }
}
