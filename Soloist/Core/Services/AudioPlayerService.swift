//
//  AudioPlayerService.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import Foundation
import AVFoundation
import Combine

// 这个类负责：真的把歌放出来
class AudioPlayerService: NSObject, ObservableObject {
    // 播放器核心对象
    private var player: AVAudioPlayer?
    
    // 向 UI 广播状态：当前正在播放哪首歌？
    @Published var currentSong: Song?
    @Published var isPlaying: Bool = false
    
    override init() {
        super.init()
        // 这里以后可以配置后台播放权限
    }
    
    func play(song: Song) {
        // 1. 如果点的就是当前这首，且暂停了，就恢复播放
        if let current = currentSong, current.id == song.id, !isPlaying {
            player?.play()
            isPlaying = true
            return
        }
        
        // 2. 否则，切歌
        do {
            // 尝试初始化播放器
            // 注意：这里可能会抛出异常（比如文件损坏），所以要用 try
            player = try AVAudioPlayer(contentsOf: song.url)
            player?.prepareToPlay()
            player?.play()
            
            // 更新状态
            self.currentSong = song
            self.isPlaying = true
            print("正在播放: \(song.title)")
            
        } catch {
            print("播放失败: \(error.localizedDescription)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func stop() {
        player?.stop()
        player = nil
        currentSong = nil
        isPlaying = false
    }
}
