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
    
    enum PersistenceError: LocalizedError {
        case missingApplicationSupportDirectory
        case unableToCreateApplicationDirectory(Error)
        case unableToEncodeSongs(Error)
        case unableToWriteLibrary(Error)
        case fileMissing
        case unableToReadLibrary(Error)
        case unableToDecodeLibrary(Error)

        var errorDescription: String? {
            switch self {
            case .missingApplicationSupportDirectory:
                return "无法找到 Application Support 目录"
            case .unableToCreateApplicationDirectory(let error):
                return "无法创建应用数据目录: \(error.localizedDescription)"
            case .unableToEncodeSongs(let error):
                return "歌曲数据编码失败: \(error.localizedDescription)"
            case .unableToWriteLibrary(let error):
                return "歌曲数据写入失败: \(error.localizedDescription)"
            case .fileMissing:
                return "本地数据库文件不存在"
            case .unableToReadLibrary(let error):
                return "本地数据库读取失败: \(error.localizedDescription)"
            case .unableToDecodeLibrary(let error):
                return "本地数据库解析失败: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - File Path Logic
    
    /// 数据库文件的存储位置
    ///
    /// 通常位于: `~/Library/Application Support/Soloist/library.json`
    ///
    /// - Returns: 指向 JSON 文件的 URL。如果无法访问沙盒目录，返回 nil。
    private static func libraryFileURL() -> Result<URL, PersistenceError> {
        let fileManager = FileManager.default
        
        // 1. 获取系统标准的 Application Support 目录
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return .failure(.missingApplicationSupportDirectory)
        }
        
        // 2. 拼接 App 专属子文件夹
        let appDir = appSupport.appendingPathComponent("Soloist")
        
        // 3. 懒加载创建目录 (Lazy Creation)
        // 如果文件夹不存在，则尝试创建它。
        if !fileManager.fileExists(atPath: appDir.path) {
            do {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                return .failure(.unableToCreateApplicationDirectory(error))
            }
        }
        
        // 4. 返回完整的文件路径
        return .success(appDir.appendingPathComponent("library.json"))
    }
    
    // MARK: - Save (Write)
    
    /// 保存歌曲列表到硬盘 (记账)
    ///
    /// 将 `[Song]` 数组编码为 JSON 数据并写入文件。
    ///
    /// - Parameter songs: 需要保存的歌曲数组。
    static func saveLibrary(songs: [Song]) -> Result<Void, PersistenceError> {
        switch libraryFileURL() {
        case .failure(let error):
            return .failure(error)
        case .success(let url):
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(songs)
                try data.write(to: url, options: .atomic)
                return .success(())
            } catch let error as EncodingError {
                return .failure(.unableToEncodeSongs(error))
            } catch {
                return .failure(.unableToWriteLibrary(error))
            }
        }
    }
    
    // MARK: - Load (Read)
    
    /// 从硬盘加载歌曲列表 
    ///
    /// App 启动时调用此方法恢复上次的状态。
    ///
    /// - Returns: 解析成功的歌曲数组。如果文件不存在或解析失败，返回空数组。
    static func loadLibrary() -> Result<[Song], PersistenceError> {
        switch libraryFileURL() {
        case .failure(let error):
            return .failure(error)
        case .success(let url):
            if !FileManager.default.fileExists(atPath: url.path) {
                return .failure(.fileMissing)
            }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let songs = try decoder.decode([Song].self, from: data)
                return .success(songs)
            } catch let error as DecodingError {
                return .failure(.unableToDecodeLibrary(error))
            } catch {
                return .failure(.unableToReadLibrary(error))
            }
        }
    }
}
