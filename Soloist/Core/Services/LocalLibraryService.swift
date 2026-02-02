//
//  LocalLibraryService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import Combine

/// 本地音乐库服务 (LocalLibraryService)
///
/// **职责**: 负责管理用户硬盘上的音乐文件夹，包括权限获取、文件扫描、歌词匹配和缓存读取。
/// **层级**: Core Layer (Service)。
///
/// 该服务采用了**“双重加载策略”**：
/// 1. **极速模式**: 优先从 Application Support 读取 `library.json` 缓存，实现秒开。
/// 2. **慢速模式**: 只有在首次运行或用户强制刷新时，才深度扫描物理硬盘。
class LocalLibraryService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前加载的所有歌曲列表
    /// UI 层监听此属性以显示列表。
    @Published var songs: [Song] = []
    
    // MARK: - Initialization
    
    init() {
        // App 启动时，自动尝试恢复上次的文件夹访问权限
        restorePermission()
    }
    
    // MARK: - Permission Management (App Sandbox)
    
    /// 保存并持久化文件夹访问权限
    ///
    /// macOS App 运行在沙盒中，用户选择文件夹后，必须将权限保存为 `BookmarkData`，
    /// 否则 App 重启后将失去访问权。
    ///
    /// - Parameter url: 用户在 NSOpenPanel 中选中的文件夹 URL。
    func scanAndSavePermission(at url: URL) {
        do {
            // 创建安全范围的书签数据 (Security Scoped Bookmark)
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "UserMusicFolderBookmark")
        } catch {
            print("❌ [LocalLibrary] 保存文件夹权限失败: \(error)")
        }
        
        // 用户手动选择文件夹意味着意图刷新，因此强制执行全盘扫描
        startAccessing(url: url, forceScan: true)
    }
    
    /// 尝试恢复上次的文件夹权限
    ///
    /// 这种机制让用户不需要每次打开 App 都重新选择音乐文件夹。
    func restorePermission() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "UserMusicFolderBookmark") else { return }
        
        var isStale = false
        do {
            // 解析书签，恢复 URL
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("⚠️ [LocalLibrary] 文件夹权限已过期 (可能文件夹被移动或重命名)")
                return
            }
            
            // 自动恢复时，默认使用缓存模式，避免每次启动都狂读硬盘
            startAccessing(url: url, forceScan: false)
        } catch {
            print("❌ [LocalLibrary] 恢复权限失败: \(error)")
        }
    }
    
    /// 开启安全访问并决定加载策略
    ///
    /// - Parameters:
    ///   - url: 音乐文件夹 URL。
    ///   - forceScan: 是否强制重新扫描硬盘。
    private func startAccessing(url: URL, forceScan: Bool) {
        if url.startAccessingSecurityScopedResource() {
            
            // 🚀 策略 A (极速模式)：优先读缓存
            if !forceScan {
                let cachedSongs = LibraryPersistenceService.loadLibrary()
                if !cachedSongs.isEmpty {
                    self.songs = cachedSongs
                    print("⚡️ [LocalLibrary] 命中本地缓存，跳过硬盘扫描")
                    return // 成功命中，直接结束
                }
            }
            
            // 🐢 策略 B (慢速模式)：缓存未命中或强制刷新 -> 扫描物理硬盘
            scanDirectory(at: url)
            
        } else {
            print("❌ [LocalLibrary] 无法获取文件夹访问权限 (startAccessing 失败)")
        }
    }
    
    // MARK: - Scanning Logic
    
    /// 执行全盘文件扫描
    ///
    /// 这是一个耗时操作，会在后台线程执行。
    ///
    /// - Parameter rootURL: 根目录 URL。
    func scanDirectory(at rootURL: URL) {
        print("🐢 [LocalLibrary] 开始全盘扫描: \(rootURL.path)")
        
        let fileManager = FileManager.default
        
        // 创建文件枚举器，跳过隐藏文件和包内容
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        Task {
            var foundSongs: [Song] = []
            var mp3URLs: [URL] = []
            
            // 1. 快速遍历：收集所有 .mp3 文件路径
            // 这一步只读路径，不读内容，速度很快
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    mp3URLs.append(fileURL)
                }
            }
            
            print("🔍 [LocalLibrary] 发现 \(mp3URLs.count) 个 MP3 文件，开始解析元数据...")
            
            // 2. 深度解析：逐个读取 ID3 和查找歌词
            for fileURL in mp3URLs {
                // 读取基础元数据 (Title, Artist, Embedded Lyrics)
                // 注意：MetadataService 不再读取封面图片，这极大地加快了扫描速度
                var song = await MetadataService.parse(url: fileURL)
                
                // --- 智能 LRC 匹配算法 ---
                // 尝试在同级目录、Lyrics 子目录、lyrics 子目录查找同名 .lrc 文件
                
                let parentDir = fileURL.deletingLastPathComponent()
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                
                let candidates = [
                    parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"), // ./Lyrics/Song.lrc
                    parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"), // ./lyrics/Song.lrc
                    fileURL.deletingPathExtension().appendingPathExtension("lrc") // ./Song.lrc (同级目录)
                ]
                
                var foundLrcURL: URL? = nil
                
                for candidate in candidates {
                    if fileManager.fileExists(atPath: candidate.path) {
                        foundLrcURL = candidate
                        break // 找到一个就停止
                    }
                }
                
                // 如果找到了外部歌词文件，更新 Song 对象
                if let lrc = foundLrcURL {
                    song = Song(
                        id: song.id,
                        url: song.url,
                        title: song.title,
                        artist: song.artist,
                        // 这里不再传入 artworkData，符合新模型定义
                        lrcURL: lrc,
                        embeddedLyrics: song.embeddedLyrics
                    )
                }
                
                foundSongs.append(song)
            }
            
            // 3. 扫描完成，立即持久化到 library.json
            LibraryPersistenceService.saveLibrary(songs: foundSongs)
            
            // 4. 回到主线程更新 UI
            await MainActor.run {
                self.songs = foundSongs
                print("✅ [LocalLibrary] 扫描完成，共加载 \(self.songs.count) 首歌")
            }
        }
    }
}
