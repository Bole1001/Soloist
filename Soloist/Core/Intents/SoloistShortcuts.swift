//
//  SoloistShortcuts.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/4/6.
//

import Foundation
import AppIntents
import AVFoundation

// MARK: - 1. 实体映射 (AppEntity)
/// 将你的内部模型转换为系统级快捷指令实体
struct PlaylistEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "歌单")
    
    // 指定查询引擎
    static let defaultQuery = PlaylistEntityQuery()
    
    // 实体标识符 (使用 String 以兼容 UUID 和 "favorites" 常量)
    let id: String
    
    @Property(title: "歌单名称")
    var name: String
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    // 系统渲染气泡时的显示名称
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: name)
    }
}

// MARK: - 2. 实体查询器 (EntityQuery)
/// 负责向快捷指令系统提供下拉菜单的数据源
struct PlaylistEntityQuery: EntityStringQuery {
    
    /// 当用户在快捷指令 UI 中点击参数时，返回所有建议的列表
    func suggestedEntities() async throws -> [PlaylistEntity] {
        return await MainActor.run {
            let manager = UserPlaylistManager()
            var entities: [PlaylistEntity] = []
            
            // 1. 强行伪造注入“我的红心收藏”作为置顶实体
            entities.append(PlaylistEntity(id: "favorites", name: "我的红心收藏"))
            
            // 2. 遍历持久化的自建歌单
            for playlist in manager.customPlaylists {
                entities.append(PlaylistEntity(id: playlist.id.uuidString, name: playlist.name))
            }
            
            return entities
        }
    }
    
    /// 当系统通过底层 ID 请求实体时
    func entities(for identifiers: [String]) async throws -> [PlaylistEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }
    
    /// 用于支持用户在快捷指令菜单中进行输入搜索匹配
    func entities(matching string: String) async throws -> [PlaylistEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

// MARK: - 3. 动作执行器 (AppIntent)
/// 核心业务逻辑：后台唤醒并水合数据进行播放
struct PlayPlaylistIntent: AppIntent {
    static let title: LocalizedStringResource = "播放指定歌单"
    static let description = IntentDescription("在 Soloist 中静默播放你选择的歌单或红心收藏。")
    
    // 暴露给用户的参数面板
    @Parameter(title: "歌单", requestValueDialog: "你想播放哪个歌单？")
    var targetPlaylist: PlaylistEntity
    
    // 后台静默执行入口
    func perform() async throws -> some IntentResult {
        // 防音频劫持的 Session 激活可以放在后台
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ AppIntent 强激活 AudioSession 失败: \(error)")
        }
        #endif
        
        try await MainActor.run {
            let manager = UserPlaylistManager()
            let library = LocalLibraryService()
            
            var targetSongIDs: [String] = []
            
            // 1. 解析意图，抽取对应的 ID 数组
            if targetPlaylist.id == "favorites" {
                targetSongIDs = manager.favoriteSongIDs
            } else {
                if let matchedPlaylist = manager.customPlaylists.first(where: { $0.id.uuidString == targetPlaylist.id }) {
                    targetSongIDs = matchedPlaylist.songIDs
                }
            }
            
            guard !targetSongIDs.isEmpty else {
                throw IntentError.message("该歌单中没有歌曲。")
            }
            
            // 2. 数据水合 (安全读取 library.songs)
            let validSongs = library.songs.filter { targetSongIDs.contains($0.id) }
            
            guard let firstSong = validSongs.first else {
                throw IntentError.message("未能在本地曲库中找到该歌单的歌曲文件。")
            }
            
            // 3. 触发播放引擎
            AudioPlayerService.shared.play(song: firstSong, playlist: validSongs)
        }
        
        return .result()
    }
}

// 供 Intent 抛出自定义交互错误的扩展
enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case message(String)
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text): return LocalizedStringResource(stringLiteral: text)
        }
    }
}

// MARK: - 4. 系统生态注册 (AppShortcutsProvider)
/// 将你的功能直接挂载到系统建议中，实现 Siri 免配置拉起
struct SoloistShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayPlaylistIntent(),
            phrases: [
                "用 \(.applicationName) 播放 \(\.$targetPlaylist)",
                "播放 \(.applicationName) 里的 \(\.$targetPlaylist)",
                "Play \(\.$targetPlaylist) on \(.applicationName)"
            ],
            shortTitle: "播放歌单",
            systemImageName: "play.circle"
        )
    }
}
