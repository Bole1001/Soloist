//
//  MusicMonitor.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import AppKit

class MusicMonitor {
    var onMusicAppLaunched: (() -> Void)?
    var onMusicAppTerminated: (() -> Void)?
    var onTrackChanged: ((String, String) -> Void)?
    
    func start() {
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
        let state = userInfo["Player State"] as? String ?? "Unknown"
        let location = userInfo["Location"] as? String ?? ""
        onTrackChanged?(state, location)
    }
}
