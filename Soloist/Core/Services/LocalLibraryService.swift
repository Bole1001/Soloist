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
    
    // 记录当前正在访问的文件夹 URL，用于释放权限
    private var accessingURL: URL?
    
    // 支持的格式列表
    private let supportedExtensions = Set(["mp3", "flac", "m4a", "wav", "aiff"])
    
    // 析构时自动释放权限，防止内存/内核资源泄漏
    deinit {
        stopAccessing()
    }

    /// 辅助方法：停止访问当前文件夹
    private func stopAccessing() {
        accessingURL?.stopAccessingSecurityScopedResource()
        accessingURL = nil
    }
    
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
        // 1. 先停止旧的访问（如果有），防止泄漏
        stopAccessing()
        
        // 2. 开始新的访问
        if url.startAccessingSecurityScopedResource() {
            self.accessingURL = url // 记录下来，以便将来释放
            
            // 策略 A (极速模式)：优先读缓存
            if !forceScan {
                let cachedSongs = LibraryPersistenceService.loadLibrary()
                if !cachedSongs.isEmpty {
                    self.songs = cachedSongs
                    print("⚡️ [LocalLibrary] 命中本地缓存，跳过硬盘扫描")
                    return
                }
            }
            
            // 策略 B (慢速模式)：扫描物理硬盘
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
        print("🐢 [LocalLibrary] 开始并发扫描: \(rootURL.path)")
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        Task {
            // 1. 快速遍历：收集所有支持的音频文件路径
            var targetURLs: [URL] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                // ✨ 修改：检查是否在支持的格式列表中
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    targetURLs.append(fileURL)
                }
            }
            
            print("🔍 [LocalLibrary] 发现 \(targetURLs.count) 个音频文件，启动并发解析...")
            
            // 2. ✨✨✨ 并发解析核心优化 ✨✨✨
            // 使用 TaskGroup 同时开启多个任务解析元数据
            let parsedSongs = await withTaskGroup(of: Song?.self, returning: [Song].self) { group in
                
                for fileURL in targetURLs {
                    group.addTask {
                        // 2.1 解析元数据 (耗时操作)
                        var song = await MetadataService.parse(url: fileURL)
                        
                        // 2.2 查找 LRC (文件操作)
                        let parentDir = fileURL.deletingLastPathComponent()
                        let baseName = fileURL.deletingPathExtension().lastPathComponent
                        
                        let candidates = [
                            parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
                            parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
                            fileURL.deletingPathExtension().appendingPathExtension("lrc")
                        ]
                        
                        var foundLrcURL: URL? = nil
                        for candidate in candidates {
                            // 注意：这里直接使用 FileManager.default 是线程安全的
                            if FileManager.default.fileExists(atPath: candidate.path) {
                                foundLrcURL = candidate
                                break
                            }
                        }
                        
                        if let lrc = foundLrcURL {
                            // 更新 Song 对象
                            song = Song(
                                id: song.id,
                                url: song.url,
                                title: song.title,
                                artist: song.artist,
                                lrcURL: lrc,
                                embeddedLyrics: song.embeddedLyrics
                            )
                        }
                        return song
                    }
                }
                
                // 收集结果
                var results: [Song] = []
                for await song in group {
                    if let song = song {
                        results.append(song)
                    }
                }
                
                // 按歌名排序
                return results.sorted { $0.title < $1.title }
            }
            
            // 3. 持久化
            LibraryPersistenceService.saveLibrary(songs: parsedSongs)
            
            // 4. 更新 UI
            await MainActor.run {
                self.songs = parsedSongs
                print("✅ [LocalLibrary] 扫描完成，共加载 \(self.songs.count) 首歌")
            }
        }
    }
}
