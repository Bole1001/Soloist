//
//  PlaylistManager.swift
//  Soloist
//
//  Created by Bole on 2026/1/31.
//

import Foundation

class PlaylistManager {
    // 逻辑私有化，外界通过方法访问
    private(set) var originalPlaylist: [Song] = []
    private(set) var shuffledPlaylist: [Song] = []
    
    // 状态配置
    var isShuffleMode: Bool = true
    var isLoopMode: Bool = true
    
    /// 设置新列表
    func updateList(_ list: [Song]) {
        self.originalPlaylist = list
    }
    
    /// 生成/重置随机列表
    func reshuffle(keepCurrentAtTop current: Song? = nil) {
        var shuffled = originalPlaylist.shuffled()
        if let current = current, let index = shuffled.firstIndex(where: { $0.id == current.id }) {
            shuffled.remove(at: index)
            shuffled.insert(current, at: 0)
        }
        self.shuffledPlaylist = shuffled
    }
    
    /// 计算下一首
    func getNextSong(after current: Song?) -> Song? {
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard !activeList.isEmpty else { return nil }
        guard let current = current, let index = activeList.firstIndex(where: { $0.id == current.id }) else {
            return activeList.first
        }
        
        let nextIndex = index + 1
        if nextIndex >= activeList.count {
            return isLoopMode ? activeList.first : nil
        }
        return activeList[nextIndex]
    }
    
    /// 计算上一首
    func getPreviousSong(before current: Song?) -> Song? {
        let activeList = isShuffleMode ? shuffledPlaylist : originalPlaylist
        guard !activeList.isEmpty else { return nil }
        guard let current = current, let index = activeList.firstIndex(where: { $0.id == current.id }) else {
            return activeList.last
        }
        
        let prevIndex = index - 1
        if prevIndex < 0 {
            return isLoopMode ? activeList.last : nil
        }
        return activeList[prevIndex]
    }
}
