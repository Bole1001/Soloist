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
    
    // 用于存储“通行证”的 Key
    private let bookmarkKey = "SavedMusicFolderBookmark"
    
    init() {
        // App 启动时，自动尝试加载上次的文件夹
        restoreFolderPermission()
    }
    
    // 1. 保存权限并开始扫描
    func scanAndSavePermission(at url: URL) {
        do {
            // 创建“安全书签” (这是核心步骤，不仅仅是存路径)
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            // 存到 UserDefaults
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            print("文件夹权限已保存")
            
            // 开始扫描
            scanDirectory(at: url)
        } catch {
            print("保存权限失败: \(error)")
        }
    }
    
    // 2. 恢复权限
    private func restoreFolderPermission() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        
        var isStale = false
        do {
            // 解析书签，变回 URL
            let url = try URL(resolvingBookmarkData: data,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("权限已过期，需要用户重新选择")
                return
            }
            
            // 关键：告诉系统“我要开始访问这个受保护的文件夹了”
            if url.startAccessingSecurityScopedResource() {
                print("自动加载文件夹: \(url.path)")
                scanDirectory(at: url)
            } else {
                print("无法访问文件夹权限")
            }
            
        } catch {
            print("恢复文件夹失败: \(error)")
        }
    }
    
    // 3. 原有的扫描逻辑 (稍微修改一下参数标签)
    func scanDirectory(at url: URL) {
        // (保持之前的代码逻辑不变)
        print("开始扫描文件夹: \(url.path)")
        
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        var foundSongs: [Song] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "mp3" {
                let filename = fileURL.deletingPathExtension().lastPathComponent
                let newSong = Song(url: fileURL, title: filename, artist: "Unknown")
                foundSongs.append(newSong)
            }
        }
        
        DispatchQueue.main.async {
            self.songs = foundSongs
            print("扫描结束，找到 \(self.songs.count) 首歌")
        }
    }
}
