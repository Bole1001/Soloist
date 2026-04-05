//
//  LocalLibraryService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import Combine
import SwiftUI

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
        let cachedSongs = LibraryPersistenceService.loadLibrary()
        if !cachedSongs.isEmpty {
            self.songs = cachedSongs
        }
        
        #if os(macOS)
        restorePermission()
        #else
        // iOS 启动时，直接扫描 Documents 目录 (加载 iTunes 共享或上次导入的文件)
        //loadLocalDocuments()
        #endif
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
            #if os(macOS)
            let options: URL.BookmarkCreationOptions = .withSecurityScope
            #else
            let options: URL.BookmarkCreationOptions = []
            #endif
            
            let bookmarkData = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "UserMusicFolderBookmark")
        } catch {
            print("❌ [LocalLibrary] 保存权限失败: \(error)")
        }
        startAccessing(url: url, forceScan: true)
    }
    
    func restorePermission() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "UserMusicFolderBookmark") else { return }
        var isStale = false
        
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale), !isStale {
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
                        // 2.1 调用 MetadataService 解析基础信息
                        let baseSong = await MetadataService.parse(url: fileURL)
                        
                        // 2.2 查找外部 LRC 文件
                        let parentDir = fileURL.deletingLastPathComponent()
                        let baseName = fileURL.deletingPathExtension().lastPathComponent
                        
                        let candidates = [
                            parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
                            parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
                            fileURL.deletingPathExtension().appendingPathExtension("lrc")
                        ]
                        
                        let foundLrcURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
                        
                        // 2.4 构建最终 Song 对象 (直接透传绝对路径)
                        return Song(
                            id: baseSong.id,      // 继承 MetadataService 生成的稳定 ID
                            url: fileURL,         // ✨ 传入真实音频 URL
                            title: baseSong.title,
                            artist: baseSong.artist,
                            lrcURL: foundLrcURL,  // ✨ 传入真实歌词 URL
                            embeddedLyrics: baseSong.embeddedLyrics
                        )
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
    
    // MARK: - Deletion Logic
        
    /// 删除指定歌曲 (同时删除关联的 LRC 文件)
    func deleteSongs(at offsets: IndexSet) {
        let fileManager = FileManager.default
        
        offsets.forEach { index in
            let song = songs[index]
            
            do {
                // 1. 删除音频文件 (调用计算属性 url)
                try fileManager.removeItem(at: song.url)
                print("🗑️ 已删除音频: \(song.title)")
                
                // 2. 尝试删除关联的歌词文件 (如果有)
                if let lrcURL = song.lrcURL {
                    try? fileManager.removeItem(at: lrcURL)
                    print("🗑️ 已删除关联歌词")
                }
            } catch {
                print("❌ 删除失败: \(error.localizedDescription)")
            }
        }
        
        // 3. 从内存数组中移除
        songs.remove(atOffsets: offsets)
        
        // 4. 更新持久化缓存
        LibraryPersistenceService.saveLibrary(songs: songs)
    }
    
    // MARK: - Public Actions
        
    /// 手动刷新当前库 (用于检测新歌)
    func refreshLibrary() {
        guard let url = accessingURL else {
            print("⚠️ [LocalLibrary] 无法刷新：当前没有挂载的文件夹")
            return
        }
        
        print("🔄 [LocalLibrary] 触发手动刷新...")
        scanDirectory(at: url)
    }
    
    // MARK: - App Sandbox Logic (App 本地存储)
        
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func importSongs(from sourceURLs: [URL]) {
        let fileManager = FileManager.default
        let destFolder = documentsDirectory
        
        for srcURL in sourceURLs {
            let accessing = srcURL.startAccessingSecurityScopedResource()
            
            defer {
                if accessing { srcURL.stopAccessingSecurityScopedResource() }
            }
            
            let destURL = destFolder.appendingPathComponent(srcURL.lastPathComponent)
            
            do {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                
                try fileManager.copyItem(at: srcURL, to: destURL)
                print("✅ [Import] 成功导入: \(srcURL.lastPathComponent)")
                
            } catch {
                print("❌ [Import] 导入失败: \(error.localizedDescription)")
            }
        }
        
        scanDirectory(at: documentsDirectory)
    }
    
    func loadLocalDocuments() {
        scanDirectory(at: documentsDirectory)
    }
}
