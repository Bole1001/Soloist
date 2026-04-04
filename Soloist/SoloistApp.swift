//
//  SoloistApp.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct SoloistApp: App {
    
    // MARK: - App Delegate Integration
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // MARK: - State Management
    
    @StateObject private var playerService = AudioPlayerService.shared
    
    // ✨ 新增 1：WebDAV 服务状态（仅限 iOS）
    #if os(iOS)
    @StateObject private var webDAVService = WebDAVService()
    @Environment(\.scenePhase) private var scenePhase
    #endif
    
    var body: some Scene {
        
        // MARK: - macOS Scene Configuration
        #if os(macOS)
        
        Window("Soloist", id: "MainWindow") {
            MacHomeView()
                .background(VisualEffect().ignoresSafeArea())
                .environmentObject(playerService)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        // MARK: - iOS Scene Configuration
        #else
        
        WindowGroup {
            IphoneHomeView()
                .environmentObject(playerService)
                // ✨ 新增 2：将服务注入到 iOS 视图树
                .environmentObject(webDAVService)
        }
        // ✨ 新增 3：生命周期安全锁（退到后台强制断开服务器）
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                webDAVService.stopServer()
            }
        }
        
        #endif
    }
}

// MARK: - Helper Views (macOS)
#if os(macOS)
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}
#endif
