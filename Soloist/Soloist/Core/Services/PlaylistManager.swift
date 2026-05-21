//
//  PlaylistManager.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation
import Combine

/// 播放列表管理器 (PlaylistManager)
///
/// **职责**: 负责维护播放队列的顺序、随机打乱算法以及“上一首/下一首”的导航逻辑。
/// **层级**: Core Layer (Service Helper)。
///
/// 该类核心逻辑在于维护两套列表：
/// 1. `originalPlaylist`: 原始顺序（如用户导入的专辑列表或文件夹顺序）。
/// 2. `shuffledPlaylist`: 随机映射表，确保随机播放时不会重复播放同一首歌，直到列表播完。
class PlaylistManager: ObservableObject {
    
    // MARK: - Data Source
    
    /// 原始播放列表
    ///
    /// 仅限内部修改，外部只读，以保证数据源的唯一性和安全性。
    @Published private(set) var originalPlaylist: [Song] = []
    
    /// 随机播放列表
    ///
    /// 当 `isShuffleMode` 为 true 时，播放器将依照此列表的顺序进行导航。
    @Published private(set) var shuffledPlaylist: [Song] = []
    
    // MARK: - Configuration
    
    /// 随机模式开关
    ///
    /// - `true`: 使用 `shuffledPlaylist` 进行导航。
    /// - `false`: 使用 `originalPlaylist` 进行导航。
    @Published var isShuffleMode: Bool = true
    
    /// 循环模式开关
    ///
    /// - `true`: 列表循环。
    /// - `false`: 顺序播放到末尾后停止。
    @Published var isLoopMode: Bool = true
    
    // MARK: - Playlist Management
    
    /// 更新原始播放列表
    ///
    /// 通常在用户导入歌曲或清空列表时调用。
    /// - Parameter list: 新的歌曲列表
    func updateList(_ list: [Song]) {
        self.originalPlaylist = list
    }
    
    /// 生成或重置随机列表
    ///
    /// 该算法包含一个人性化设计：如果当前正在播放某首歌，
    /// 这首歌会被强制固定在随机列表的第一位，
    /// 从而保证用户开启随机模式时，不会突然切歌，而是从当前这首继续往后听。
    ///
    /// - Parameter current: 当前正在播放的歌曲（可选）。
    func reshuffle(keepCurrentAtTop current: Song? = nil) {
        // 使用 Swift 标准库的洗牌算法 (Fisher-Yates)
        var shuffled = originalPlaylist.shuffled()
        
        // 如果有当前歌曲，将其移动到队列头部
        if let current = current, let index = shuffled.firstIndex(where: { $0.id == current.id }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        
        self.shuffledPlaylist = shuffled
    }
    
    // MARK: - Navigation Logic
    
    /// 计算下一首歌曲
    ///
    /// 根据当前的随机模式和循环模式，决定下一首播放什么。
    ///
    /// - Parameter current: 当前正在播放的歌曲。
    /// - Returns: 下一首歌曲对象。如果列表已播完且未开启循环，则返回 nil。
    func getNextSong(after current: Song?) -> Song? {
        // 1. 确定当前生效的列表
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard !activeList.isEmpty else { return nil }
        
        // 2. 找到当前歌曲的下标
        // 如果当前没在播放，或者当前歌曲不在列表中，默认从第一首开始
        guard let current = current, let index = activeList.firstIndex(where: { $0.id == current.id }) else {
            return activeList.first
        }
        
        // 3. 计算下一首的下标
        let nextIndex = index + 1
        
        // 4. 处理边界情况
        if nextIndex >= activeList.count {
            // 到达队尾：如果是循环模式，回到队头；否则结束。
            return isLoopMode ? activeList.first : nil
        }
        
        return activeList[nextIndex]
    }
    
    /// 计算上一首歌曲
    ///
    /// - Parameter current: 当前正在播放的歌曲。
    /// - Returns: 上一首歌曲对象。
    func getPreviousSong(before current: Song?) -> Song? {
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard !activeList.isEmpty else { return nil }
        
        guard let current = current, let index = activeList.firstIndex(where: { $0.id == current.id }) else {
            // 如果找不到当前歌曲，默认去列表最后一首（符合直觉）
            return activeList.last
        }
        
        let prevIndex = index - 1
        
        // 处理边界情况
        if prevIndex < 0 {
            // 到达队头：如果是循环模式，跳到队尾；否则结束。
            return isLoopMode ? activeList.last : nil
        }
        
        return activeList[prevIndex]
    }
    
    // MARK: - List Update Helpers
        
    /// 更新原始列表（用于顺序模式下的排序/删除）
    func updateOriginalList(_ list: [Song]) {
        self.originalPlaylist = list
    }
    
    /// 更新随机列表（用于随机模式下的排序/删除）
    func updateShuffledList(_ list: [Song]) {
        self.shuffledPlaylist = list
    }
    
    // MARK: - Handoff Sync Helpers
        
    /// 获取滑动窗口缓冲 (提取当前歌曲及后续 10 首歌的 ID，保持绝对真实顺序)
    func getSlidingWindowIDs(after current: Song?, limit: Int = 10) -> [String] {
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard let current = current,
              let index = activeList.firstIndex(where: { $0.id == current.id }) else {
            return []
        }
        
        // 我们不截取前面播放过的歌，只取当前歌曲及未来的歌
        let endIndex = min(index + 1 + limit, activeList.count)
        return activeList[index..<endIndex].map { $0.id }
    }
}
