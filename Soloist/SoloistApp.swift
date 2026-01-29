//
//  SoloistApp.swift
//  Soloist
//
//  Created by Bole on 2026/1/28.
//

import SwiftUI

@main
struct SoloistApp: App {
    var body: some Scene {
        WindowGroup {
            MacHomeView()
                // 确保背景色能延伸到最顶部的"红绿灯"区域
                .background(VisualEffect().ignoresSafeArea())
        }
        // ✨ 核心修改：隐藏标题栏，内容满铺
        .windowStyle(.hiddenTitleBar)
    }
}

// ✨ 一个小辅助组件：让窗口背景支持“毛玻璃”透视效果 (可选，但加上更有质感)
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow // 窗口背景混合模式
        view.state = .active
        view.material = .sidebar // 使用侧边栏那种深色半透明材质
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}
