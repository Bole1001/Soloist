//
//  LocalLibraryService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import Combine

class LocalLibraryService: ObservableObject {
    
    @Published var songs: [Song] = []
    
    // 初始化时自动调用恢复权限
    init() {
        restorePermission()
    }
    
    // 保存用户授权的文件夹权限
    func scanAndSavePermission(at url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "UserMusicFolderBookmark")
        } catch {
            print("保存文件夹权限失败: \(error)")
        }
        // 用户手动选择文件夹时，强制进行一次扫描
        startAccessing(url: url, forceScan: true)
    }
    
    // 尝试恢复上次的文件夹权限
    func restorePermission() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "UserMusicFolderBookmark") else { return }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale { return }
            
            // 启动恢复时，不强制扫描，优先读缓存
            startAccessing(url: url, forceScan: false)
        } catch {
            print("恢复权限失败: \(error)")
        }
    }
    
    // 控制是“读缓存”还是“真扫描”
    private func startAccessing(url: URL, forceScan: Bool) {
        if url.startAccessingSecurityScopedResource() {
            
            if !forceScan {
                // 🚀 策略 A (极速模式)：尝试从 JSON 数据库加载
                let cachedSongs = LibraryPersistenceService.loadLibrary()
                if !cachedSongs.isEmpty {
                    self.songs = cachedSongs
                    print("⚡️ [LocalLibrary] 命中本地缓存，跳过硬盘扫描")
                    return // 直接结束，不执行下面的扫描逻辑
                }
            }
            
            // 🐢 策略 B (慢速模式)：缓存为空，或者用户强制刷新 -> 扫描硬盘
            scanDirectory(at: url)
            
        } else {
            print("无法获取文件夹访问权限")
        }
    }
    
    // 核心扫描逻辑
    func scanDirectory(at rootURL: URL) {
        print("🐢 [LocalLibrary] 开始全盘扫描: \(rootURL.path)")
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        Task {
            var foundSongs: [Song] = []
            var mp3URLs: [URL] = []
            
            // 1. 先快速收集所有的 mp3 文件路径
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.pathExtension.lowercased() == "mp3" {
                    mp3URLs.append(fileURL)
                }
            }
            
            // 2. 逐个解析
            for fileURL in mp3URLs {
                // 先拿到基础信息的 Song 对象 (此时 MetadataService 已经不读图片了)
                var song = await MetadataService.parse(url: fileURL)
                
                // --- 智能寻找 LRC 歌词文件 ---
                let parentDir = fileURL.deletingLastPathComponent()
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                
                let lyricsFolderURL = parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc")
                let lowerLyricsFolderURL = parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc")
                let sameFolderURL = fileURL.deletingPathExtension().appendingPathExtension("lrc")
                
                var foundLrcURL: URL? = nil
                
                if fileManager.fileExists(atPath: lyricsFolderURL.path) {
                    foundLrcURL = lyricsFolderURL
                } else if fileManager.fileExists(atPath: lowerLyricsFolderURL.path) {
                    foundLrcURL = lowerLyricsFolderURL
                } else if fileManager.fileExists(atPath: sameFolderURL.path) {
                    foundLrcURL = sameFolderURL
                }
                
                // 如果找到了歌词，创建新 Song 替换
                if let lrc = foundLrcURL {
                    song = Song(
                        id: song.id,
                        url: song.url,
                        title: song.title,
                        artist: song.artist,
                        // ❌ 删除了 artworkData: song.artworkData
                        lrcURL: lrc,
                        embeddedLyrics: song.embeddedLyrics
                    )
                }
                
                foundSongs.append(song)
            }
            
            // 3. 扫描完成后，立刻保存到本地数据库
            LibraryPersistenceService.saveLibrary(songs: foundSongs)
            
            // 4. 回到主线程刷新 UI
            await MainActor.run {
                self.songs = foundSongs
            }
        }
    }
}
