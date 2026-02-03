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
    
    // 使用 AppKit 的 AppDelegate 接管生命周期和菜单栏逻辑
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    // MARK: - State Management
    
    // 依然保留，用于主窗口内部的逻辑
    @StateObject private var playerService = AudioPlayerService.shared
    
    var body: some Scene {
        
        // MARK: - macOS Scene Configuration
        #if os(macOS)
        
        // 1. 主应用程序窗口
        Window("Soloist", id: "MainWindow") {
            MacHomeView()
                .background(VisualEffect().ignoresSafeArea())
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        // MARK: - iOS Scene Configuration
        #else
        
        WindowGroup {
            if #available(iOS 16.0, *) {
                Text("iOS 端主页开发中...")
            } else {
                Text("iOS 端主页开发中...")
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
