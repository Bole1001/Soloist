//
//  MusicMonitor.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import AppKit

class MusicMonitor {
    enum PlaybackState: String {
        case playing = "Playing"
        case paused = "Paused"
        case stopped = "Stopped"
        case unknown = "Unknown"
    }
    
    struct TrackEvent: Equatable {
        let state: PlaybackState
        let location: String
        let playerName: String?
        let artist: String?
        let title: String?
    }
    
    var onMusicAppLaunched: (() -> Void)?
    var onMusicAppTerminated: (() -> Void)?
    var onTrackChanged: ((TrackEvent) -> Void)?
    
    private var isMonitoring = false
    private var lastTrackEvent: TrackEvent?
    
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(appLaunched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(appTerminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(musicPlayerStateChanged(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
    }
    
    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        lastTrackEvent = nil
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    @objc private func appLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.bundleIdentifier == "com.apple.Music" {
            onMusicAppLaunched?()
        }
    }
    
    @objc private func appTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if app.bundleIdentifier == "com.apple.Music" {
            onMusicAppTerminated?()
        }
    }
    
    @objc private func musicPlayerStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let state = resolvePlaybackState(from: userInfo)
        let location = resolveStringValue(for: ["Location", "Location URL", "File Path"], in: userInfo) ?? ""
        let playerName = resolveStringValue(for: ["Player Name", "Player"], in: userInfo)
        let artist = resolveStringValue(for: ["Artist", "Track Artist", "Album Artist"], in: userInfo)
        let title = resolveStringValue(for: ["Name", "Title", "Song Name"], in: userInfo)
        
        let event = TrackEvent(
            state: state,
            location: location,
            playerName: playerName,
            artist: artist,
            title: title
        )
        
        guard event != lastTrackEvent else { return }
        lastTrackEvent = event
        onTrackChanged?(event)
    }
    
    private func resolvePlaybackState(from userInfo: [AnyHashable: Any]) -> PlaybackState {
        let rawState = resolveStringValue(for: ["Player State", "Playback State", "State"], in: userInfo) ?? ""
        let normalizedState = rawState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch normalizedState {
        case "playing", "play":
            return .playing
        case "paused", "pause":
            return .paused
        case "stopped", "stop":
            return .stopped
        default:
            return .unknown
        }
    }
    
    private func resolveStringValue(for keys: [String], in userInfo: [AnyHashable: Any]) -> String? {
        for key in keys {
            if let value = userInfo[key] as? String, !value.isEmpty {
                return value
            }
            if let value = userInfo[key] as? CustomStringConvertible {
                let stringValue = value.description
                if !stringValue.isEmpty {
                    return stringValue
                }
            }
        }
        return nil
    }
}
