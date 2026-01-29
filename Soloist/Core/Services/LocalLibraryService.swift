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
    
    // ✨ 修复点：初始化时自动调用恢复权限
    init() {
        restorePermission()
    }
    
    // 保存用户授权的文件夹权限 (macOS 沙盒机制需要)
    func scanAndSavePermission(at url: URL) {
        // 1. 获取安全访问权限 (Bookmark)
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "UserMusicFolderBookmark")
        } catch {
            print("保存文件夹权限失败: \(error)")
        }
        
        // 2. 开始扫描
        startAccessing(url: url)
    }
    
    // 尝试恢复上次的文件夹权限
    func restorePermission() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "UserMusicFolderBookmark") else { return }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("权限标签已过期，需要重新选择")
                return
            }
            
            print("成功恢复上次的文件夹权限: \(url.path)")
            startAccessing(url: url)
        } catch {
            print("恢复权限失败: \(error)")
        }
    }
    
    private func startAccessing(url: URL) {
        if url.startAccessingSecurityScopedResource() {
            scanDirectory(at: url)
        } else {
            print("无法获取文件夹访问权限")
        }
    }
    
    // 核心扫描逻辑
    func scanDirectory(at rootURL: URL) {
        print("开始扫描文件夹: \(rootURL.path)")
        
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
                var song = await MetadataService.parse(url: fileURL)
                
                // 智能寻找 LRC 歌词文件 (支持 Lyrics 文件夹)
                let parentDir = fileURL.deletingLastPathComponent()
                let baseName = fileURL.deletingPathExtension().lastPathComponent
                
                let lyricsFolderURL = parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc")
                let lowerLyricsFolderURL = parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc")
                let sameFolderURL = fileURL.deletingPathExtension().appendingPathExtension("lrc")
                
                if fileManager.fileExists(atPath: lyricsFolderURL.path) {
                    song.lrcURL = lyricsFolderURL
                } else if fileManager.fileExists(atPath: lowerLyricsFolderURL.path) {
                    song.lrcURL = lowerLyricsFolderURL
                } else if fileManager.fileExists(atPath: sameFolderURL.path) {
                    song.lrcURL = sameFolderURL
                }
                
                foundSongs.append(song)
            }
            
            // 3. 回到主线程刷新 UI
            await MainActor.run {
                self.songs = foundSongs
            }
        }
    }
}
