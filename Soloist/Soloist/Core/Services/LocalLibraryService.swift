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

    enum LocalLibraryError: LocalizedError {
        case missingBookmark
        case invalidBookmarkData
        case staleBookmarkData
        case securityScopedAccessDenied
        case persistenceFailed(LibraryPersistenceService.PersistenceError)
        case deleteFailed(URL, Error)
        case copyFailed(URL, Error)
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .missingBookmark:
                return "未找到已保存的文件夹权限"
            case .invalidBookmarkData:
                return "文件夹权限数据无效"
            case .staleBookmarkData:
                return "文件夹权限已失效"
            case .securityScopedAccessDenied:
                return "无法获取文件夹访问权限"
            case .persistenceFailed(let error):
                return error.localizedDescription
            case .deleteFailed(let url, let error):
                return "删除失败 \(url.lastPathComponent): \(error.localizedDescription)"
            case .copyFailed(let url, let error):
                return "导入失败 \(url.lastPathComponent): \(error.localizedDescription)"
            case .emptySelection:
                return "未选择任何文件"
            }
        }
    }

    // MARK: - Published Properties

    /// 当前加载的所有歌曲列表
    @Published var songs: [Song] = []
    
    /// 用于 O(1) 极速查询的哈希字典，必须与 songs 严格保持同步
    @Published var songDictionary: [String: Song] = [:]
    
    // MARK: - Private Properties
    
    /// 记录当前正在访问的文件夹 URL，用于后续释放权限
    @Published var accessingURL: URL?
    
    /// 最近一次可见错误，供 UI 或调试层读取
    @Published var lastError: LocalLibraryError?

    /// 支持扫描的音频格式
    private let supportedExtensions = Set(["mp3", "flac", "m4a", "wav", "aiff", "ogg"])
    
    // MARK: - Lifecycle
    
    init() {
        let cachedSongs = loadCachedSongs()
        self.songs = cachedSongs
        self.songDictionary = makeSongDictionary(from: cachedSongs)

        // 启动时优先恢复已保存的文件夹权限，保证上次授权的音乐库能自动回到可用状态。
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
    
    @discardableResult
    func restorePermission() -> Result<Void, LocalLibraryError> {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "UserMusicFolderBookmark") else {
            // 新安装或用户尚未选择文件夹时，不把“没有保存过权限”当成错误。
            return .success(())
        }
        var isStale = false

        let options: URL.BookmarkResolutionOptions = []

        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard !isStale else {
                return reportError(.staleBookmarkData)
            }
            return startAccessing(url: url, forceScan: false)
        } catch {
            return reportError(.invalidBookmarkData)
        }
    }
    
    @discardableResult
    private func startAccessing(url: URL, forceScan: Bool) -> Result<Void, LocalLibraryError> {
        stopAccessing() // 先释放旧的

        guard url.startAccessingSecurityScopedResource() else {
            return reportError(.securityScopedAccessDenied)
        }

        self.accessingURL = url

        // 策略A：读缓存
        if !forceScan {
            let cached = loadCachedSongs()
            if !cached.isEmpty {
                self.songs = cached
                print("⚡️ [LocalLibrary] 命中缓存，跳过扫描")
                return .success(())
            }
        }
        // 策略B：全盘扫描
        scanDirectory(at: url)
        return .success(())
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
            // 1. 快速遍历：仅收集文件路径
            var targetURLs: [URL] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    targetURLs.append(fileURL)
                }
            }
            
            print("🔍 [LocalLibrary] 发现 \(targetURLs.count) 个音频文件，启动受限并发解析...")
            
            // 2. 受限并发 (滑动窗口模式)
            let parsedSongs = await withTaskGroup(of: Song?.self, returning: [Song].self) { group in
                let maxConcurrency = 15 // 绝对红线：最多同时打开 15 个文件
                var iterator = targetURLs.makeIterator()
                var activeTasks = 0
                
                // 预加载第一批任务
                while activeTasks < maxConcurrency, let fileURL = iterator.next() {
                    group.addTask { await self.parseSingleFile(fileURL) }
                    activeTasks += 1
                }
                
                // 使用字典来收集并发结果
                var uniqueResults: [String: Song] = [:]
                
                for await song in group {
                    if let song = song {
                        // 如果有重复 ID 的文件，后解析的会覆盖先解析的
                        uniqueResults[song.id] = song
                    }
                    
                    if let fileURL = iterator.next() {
                        group.addTask { await self.parseSingleFile(fileURL) }
                    } else {
                        activeTasks -= 1
                    }
                }
                
                // 将去重后的字典 values 转回数组，并进行排序
                return Array(uniqueResults.values).sorted { $0.title < $1.title }
            }
            
            // 3. 持久化缓存 (此时传进去的 parsedSongs 已经是绝对去重的了)
            _ = persistSongs(parsedSongs)
            
            // 4. 广播垃圾回收信号
            let validIDs = Set(parsedSongs.map { $0.id })
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil, userInfo: ["validIDs": validIDs])
            
            // 5. 回到主线程更新 UI
            await MainActor.run {
                self.songs = parsedSongs
                
                // 使用 uniquingKeysWith 构造字典，彻底封死崩溃路径
                self.songDictionary = Dictionary(
                    parsedSongs.map { ($0.id, $0) },
                    uniquingKeysWith: { (old, new) in new }
                )
                
                print("✅ [LocalLibrary] 扫描完成，共加载 \(self.songs.count) 首歌 (已过滤重复元数据)")
            }
        }
    }

    /// 私有辅助方法：解析单首歌曲（将之前的嵌套逻辑抽离，保持代码清晰）
    private func parseSingleFile(_ fileURL: URL) async -> Song? {
        let baseSong = await MetadataService.parse(url: fileURL)
        let parentDir = fileURL.deletingLastPathComponent()
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        
        let candidates = [
            parentDir.appendingPathComponent("Lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
            parentDir.appendingPathComponent("lyrics").appendingPathComponent(baseName).appendingPathExtension("lrc"),
            fileURL.deletingPathExtension().appendingPathExtension("lrc")
        ]
        
        let foundLrcURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })
        
        return Song(
            id: baseSong.id,
            url: fileURL,
            title: baseSong.title,
            artist: baseSong.artist,
            lrcURL: foundLrcURL,
            embeddedLyrics: baseSong.embeddedLyrics
        )
    }

    // MARK: - Deletion Logic
        
    /// 删除指定歌曲 (同时删除关联的 LRC 文件)
    @discardableResult
    func deleteSongs(at offsets: IndexSet) -> Result<Void, LocalLibraryError> {
        let fileManager = FileManager.default
        var firstError: LocalLibraryError?
        
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
                let localError = LocalLibraryError.deleteFailed(song.url, error)
                firstError = firstError ?? localError
                print("❌ 删除失败: \(localError.localizedDescription)")
            }
        }
        
        // 3. 从内存数组中移除
        let removedSongs = offsets.map { songs[$0] }
        songs.remove(atOffsets: offsets)
        
        // 同步移除字典中的数据
        for song in removedSongs {
            songDictionary.removeValue(forKey: song.id)
        }
        
        // 4. 更新持久化缓存
        let saveResult = persistSongs(songs)
        return combine(firstError.map { .failure($0) } ?? .success(()), saveResult)
    }

    // MARK: - Public Actions
        
    /// 手动刷新当前库 (用于检测新歌)
    @discardableResult
    func refreshLibrary(silentIfNoAccess: Bool = false) -> Result<Void, LocalLibraryError> {
        guard let url = accessingURL else {
            if silentIfNoAccess {
                return .success(())
            }
            return reportError(.missingBookmark)
        }
        
        print("🔄 [LocalLibrary] 触发手动刷新...")
        scanDirectory(at: url)
        return .success(())
    }

    // MARK: - App Sandbox Logic (App 本地存储)
        
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @discardableResult
    func importSongs(from sourceURLs: [URL]) -> Result<Void, LocalLibraryError> {
        let fileManager = FileManager.default
        let destFolder = documentsDirectory
        var firstError: LocalLibraryError?

        guard !sourceURLs.isEmpty else {
            return reportError(.emptySelection)
        }
        
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
                let localError = LocalLibraryError.copyFailed(srcURL, error)
                firstError = firstError ?? localError
                print("❌ [Import] 导入失败: \(localError.localizedDescription)")
            }
        }
        
        scanDirectory(at: documentsDirectory)
        return firstError.map { .failure($0) } ?? .success(())
    }

    @discardableResult
    func loadLocalDocuments() -> Result<Void, LocalLibraryError> {
        scanDirectory(at: documentsDirectory)
        return .success(())
    }

    // MARK: - Persistence Helpers

    private func loadCachedSongs() -> [Song] {
        switch LibraryPersistenceService.loadLibrary() {
        case .success(let songs):
            print("📂 [Persistence] 成功从本地数据库加载 \(songs.count) 首歌")
            return songs
        case .failure(let error):
            if case .fileMissing = error {
                print("⚠️ [Persistence] 本地数据库不存在，准备初始化为空库...")
            } else {
                _ = reportError(.persistenceFailed(error))
            }
            return []
        }
    }

    @discardableResult
    private func persistSongs(_ songs: [Song]) -> Result<Void, LocalLibraryError> {
        switch LibraryPersistenceService.saveLibrary(songs: songs) {
        case .success:
            print("💾 [Persistence] 成功保存 \(songs.count) 首歌到本地数据库")
            return .success(())
        case .failure(let error):
            let localError = LocalLibraryError.persistenceFailed(error)
            return reportError(localError)
        }
    }

    private func makeSongDictionary(from songs: [Song]) -> [String: Song] {
        Dictionary(
            songs.map { ($0.id, $0) },
            uniquingKeysWith: { _, newValue in
                newValue
            }
        )
    }

    @discardableResult
    private func reportError(_ error: LocalLibraryError) -> Result<Void, LocalLibraryError> {
        lastError = error
        print("❌ [LocalLibrary] \(error.localizedDescription)")
        return .failure(error)
    }

    private func combine(_ lhs: Result<Void, LocalLibraryError>, _ rhs: Result<Void, LocalLibraryError>) -> Result<Void, LocalLibraryError> {
        switch (lhs, rhs) {
        case (.success, .success):
            return .success(())
        case (.failure(let error), _):
            return .failure(error)
        case (_, .failure(let error)):
            return .failure(error)
        }
    }
}

extension Notification.Name {
    /// 曲库扫描完成信号
    static let libraryDidUpdate = Notification.Name("SoloistLibraryDidUpdate")
}
