//
//  UserPlaylistManager.swift
//  Soloist
//
//  Created by Bole on 2026/4/4.
//

import Foundation
import Combine

/// 用户歌单模型
struct UserPlaylist: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var songIDs: [String]
}

/// 用户歌单管理器 (核心业务服务)
/// 职责: 管理红心收藏、用户自建歌单的内存状态与 JSON 落盘
class UserPlaylistManager: ObservableObject {
    
    @Published var favoriteSongIDs: Set<String> = [] {
        didSet { saveFavorites() }
    }
    
    @Published var customPlaylists: [UserPlaylist] = [] {
        didSet { saveCustomPlaylists() }
    }
    
    private let playlistsFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("user_playlists.json")
    }()
    
    init() {
        loadFavorites()
        loadCustomPlaylists()
    }
    
    // MARK: - Favorites Logic
    
    func toggleFavorite(songID: String) {
        if favoriteSongIDs.contains(songID) {
            favoriteSongIDs.remove(songID)
        } else {
            favoriteSongIDs.insert(songID)
        }
    }
    
    func isFavorite(songID: String) -> Bool {
        return favoriteSongIDs.contains(songID)
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteSongIDs), forKey: "FavoriteSongIDs")
    }
    
    private func loadFavorites() {
        if let savedArray = UserDefaults.standard.stringArray(forKey: "FavoriteSongIDs") {
            self.favoriteSongIDs = Set(savedArray)
        }
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
