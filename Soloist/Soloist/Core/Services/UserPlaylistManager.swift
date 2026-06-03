//
//  UserPlaylistManager.swift
//  Soloist
//
//  Created by Bole on 2026/4/4.
//

import Foundation
import Combine
import SwiftUI

/// 用户歌单模型
struct UserPlaylist: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var songIDs: [String]
}

/// 用户歌单管理器 (核心业务服务)
/// 职责: 管理红心收藏、用户自建歌单的内存状态与 JSON 落盘
class UserPlaylistManager: ObservableObject {
    
    @Published var favoriteSongIDs: [String] = [] {
        didSet { saveFavorites() }
    }
    
    @Published var customPlaylists: [UserPlaylist] = [] {
        didSet { saveCustomPlaylists() }
    }
    
    // 用于挂载 Combine 订阅
    private var cancellables = Set<AnyCancellable>()
    
    private let playlistsFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("user_playlists.json")
    }()

    init() {
        loadFavorites()
        loadCustomPlaylists()
        bindLibraryUpdates()
    }

    deinit {
        cancellables.removeAll()
    }

    private func bindLibraryUpdates() {
        // 监听曲库刷新信号，执行垃圾回收
        NotificationCenter.default.publisher(for: .libraryDidUpdate)
            .compactMap { $0.userInfo?["validIDs"] as? Set<String> }
            .receive(on: RunLoop.main) // 确保清理操作在主线程触发 UI 更新
            .sink { [weak self] validIDs in
                self?.cleanupGhostIDs(validIDs: validIDs)
            }
            .store(in: &cancellables)
    }
    
    /// 核心垃圾回收逻辑：剔除硬盘上已经不存在的歌曲 ID
    private func cleanupGhostIDs(validIDs: Set<String>) {
        // 1. 红心去重 (取交集，瞬间剔除无效 ID)
        let oldFavCount = favoriteSongIDs.count
        favoriteSongIDs.removeAll { !validIDs.contains($0) }
        let favRemoved = oldFavCount - favoriteSongIDs.count
        
        // 2. 歌单去重
        var playlistRemoved = 0
        for i in 0..<customPlaylists.count {
            let oldCount = customPlaylists[i].songIDs.count
            // 删除所有不在 validIDs 集合中的 ID
            customPlaylists[i].songIDs.removeAll { !validIDs.contains($0) }
            playlistRemoved += (oldCount - customPlaylists[i].songIDs.count)
        }
        
        if favRemoved > 0 || playlistRemoved > 0 {
            print("🧹 [GC] 幽灵数据清理完成：剔除红心 \(favRemoved) 首，歌单 \(playlistRemoved) 首。")
        }
    }
    
    // MARK: - Favorites Logic
    
    func toggleFavorite(songID: String) {
        if let index = favoriteSongIDs.firstIndex(of: songID) {
            favoriteSongIDs.remove(at: index) // 已存在则删除
        } else {
            favoriteSongIDs.insert(songID, at: 0) // 不存在则插入到最开头（收藏时间倒序）
        }
    }

    func isFavorite(songID: String) -> Bool {
        favoriteSongIDs.contains(songID)
    }

    private func saveFavorites() {
        // 直接存数组，不再需要 Array() 转换
        UserDefaults.standard.set(favoriteSongIDs, forKey: "FavoriteSongIDs")
    }

    private func loadFavorites() {
        if let savedArray = UserDefaults.standard.stringArray(forKey: "FavoriteSongIDs") {
            self.favoriteSongIDs = savedArray // 直接赋值
        }
    }
    
    /// 红心列表的拖拽排序
    func moveFavorites(from source: IndexSet, to destination: Int) {
        favoriteSongIDs.move(fromOffsets: source, toOffset: destination)
    }
    
    // MARK: - Custom Playlists Logic
    
    func createPlaylist(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        customPlaylists.append(UserPlaylist(name: trimmedName, songIDs: []))
    }
    
    func deletePlaylist(id: UUID) {
        customPlaylists.removeAll { $0.id == id }
    }
    
    func addSong(_ songID: String, toPlaylist playlistID: UUID) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !customPlaylists[index].songIDs.contains(songID) {
            customPlaylists[index].songIDs.append(songID)
        }
    }
    
    func removeSong(_ songID: String, fromPlaylist playlistID: UUID) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == playlistID }) else { return }
        customPlaylists[index].songIDs.removeAll { $0 == songID }
    }
    
    /// 拖拽重排自建歌单中的歌曲
    func moveSongs(inPlaylist playlistID: UUID, from source: IndexSet, to destination: Int) {
        guard let index = customPlaylists.firstIndex(where: { $0.id == playlistID }) else { return }
        
        // 执行数组元素的移动，这会自动触发 @Published 的 didSet 并落盘保存到 JSON
        customPlaylists[index].songIDs.move(fromOffsets: source, toOffset: destination)
    }
    
    private func saveCustomPlaylists() {
        do {
            let data = try JSONEncoder().encode(customPlaylists)
            try data.write(to: playlistsFileURL, options: .atomic)
        } catch {
            print("❌ 保存歌单 JSON 失败: \(error)")
        }
    }
    
    private func loadCustomPlaylists() {
        guard FileManager.default.fileExists(atPath: playlistsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: playlistsFileURL)
            self.customPlaylists = try JSONDecoder().decode([UserPlaylist].self, from: data)
        } catch {
            print("⚠️ 加载歌单 JSON 失败: \(error)")
        }
    }
}
