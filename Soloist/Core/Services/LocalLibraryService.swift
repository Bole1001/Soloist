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
/// **职责**: 负责管理用户硬盘上的音乐文件夹，包括权限获取、并发扫描、LRC 歌词匹配。
/// **层级**: Core Layer (Service)。
class LocalLibraryService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前加载的所有歌曲列表
    @Published var songs: [Song] = []
    
    // MARK: - Private Properties
    
    /// 记录当前正在访问的文件夹 URL，用于后续释放权限
    @Published var accessingURL: URL?
    
    /// 支持扫描的音频格式
    private let supportedExtensions = Set(["mp3", "flac", "m4a", "wav", "aiff", "ogg"])
    
    // MARK: - Lifecycle
    
    init() {
        restorePermission()
    }
    
    /// 析构时自动释放权限，防止资源泄漏
    deinit {
        stopAccessing()
    }
    
    // MARK: - Permission Management
    
    private func stopAccessing() {
        accessingURL?.stopAccessingSecurityScopedResource()
        accessingURL = nil
    }
    
    func scanAndSavePermission(at url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "UserMusicFolderBookmark")
        } catch {
            print("❌ [LocalLibrary] 保存权限失败: \(error)")
        }
        startAccessing(url: url, forceScan: true)
    }
    
    func restorePermission() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "UserMusicFolderBookmark") else { return }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale), !isStale {
            startAccessing(url: url, forceScan: false)
        }
    }
    
    private func startAccessing(url: URL, forceScan: Bool) {
        stopAccessing() // 先释放旧的
        
        if url.startAccessingSecurityScopedResource() {
            self.accessingURL = url
            
            // 策略A：读缓存
            if !forceScan {
                let cached = LibraryPersistenceService.loadLibrary()
                if !cached.isEmpty {
                    self.songs = cached
                    print("⚡️ [LocalLibrary] 命中缓存，跳过扫描")
                    return
                }
            }
            // 策略B：全盘扫描
            scanDirectory(at: url)
        }
    }
    
    // MARK: - Concurrent Scanning Logic
    
    func scanDirectory(at rootURL: URL) {
        print("🐢 [LocalLibrary] 开始并发扫描: \(rootURL.path)")
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        Task {
            // 1. 快速遍历：仅收集文件路径 (串行操作，速度极快)
            var targetURLs: [URL] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    targetURLs.append(fileURL)
                }
            }
            
            print("🔍 [LocalLibrary] 发现 \(targetURLs.count) 个音频文件，启动并发解析...")
            
            // 2. 并发解析核心 (TaskGroup)
            let parsedSongs = await withTaskGroup(of: Song?.self, returning: [Song].self) { group in
                
                for fileURL in targetURLs {
                    group.addTask {
                        // 2.1 调用 MetadataService 解析基础信息 (不含图片)
                        let baseSong = await MetadataService.parse(url: fileURL)
                        
                        // 2.2 查找外部 LRC 文件 (IO 操作)
                        let parentDir = fileURL.deletingLastPathComponent()
                        let baseName = fileURL.deletingPathExtension().lastPathComponent
                        
                        // 歌词查找规则：同级目录、Lyrics 子目录
                        let candidates = [
                            parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
                            parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
                            fileURL.deletingPathExtension().appendingPathExtension("lrc")
                        ]
                        
                        // 2.3 检查是否存在 LRC
                        let foundLrcURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
                        
                        // 2.4 构建最终 Song 对象
                        if let lrc = foundLrcURL {
                            return Song(
                                id: baseSong.id,         // 保持原 ID
                                url: baseSong.url,
                                title: baseSong.title,
                                artist: baseSong.artist,
                                lrcURL: lrc,             // ✨ 注入 LRC 路径
                                embeddedLyrics: baseSong.embeddedLyrics
                            )
                        } else {
                            // 没找到 LRC，直接返回 MetadataService 解析出的基础对象
                            return baseSong
                        }
                    }
                }
                
                // 3. 收集结果
                var results: [Song] = []
                for await song in group {
                    if let song = song { results.append(song) }
                }
                
                // 4. 排序 (按标题 A-Z)
                return results.sorted { $0.title < $1.title }
            }
            
            // 5. 持久化缓存
            LibraryPersistenceService.saveLibrary(songs: parsedSongs)
            
            // 6. 回到主线程更新 UI
            await MainActor.run {
                self.songs = parsedSongs
                print("✅ [LocalLibrary] 扫描完成，共加载 \(self.songs.count) 首歌")
            }
        }
    }
    
    // MARK: - Public Actions
        
    /// 手动刷新当前库 (用于检测新歌)
    /// 用户点击“刷新”按钮时调用此方法，无需重新选择文件夹
    func refreshLibrary() {
        // 确保当前有正在访问的文件夹
        guard let url = accessingURL else {
            print("⚠️ [LocalLibrary] 无法刷新：当前没有挂载的文件夹")
            return
        }
        
        print("🔄 [LocalLibrary] 触发手动刷新...")
        
        // 直接复用当前 URL 进行强制扫描
        // 触发 TaskGroup 重新遍历硬盘 -> 更新内存 -> 写入 JSON
        scanDirectory(at: url)
    }
}
