//
//  TouchBarManager.swift
//  Soloist
//
//  Created by Bole on 2026/1/30.
//

import AppKit
import SwiftUI
// 只有开启了私有功能，才需要引入 ObjC Runtime
#if PRIVATE_TOUCHBAR
import ObjectiveC
#endif

/// Touch Bar 管理器
///
/// 使用编译标记 `PRIVATE_TOUCHBAR` 控制。
/// - 开启时：使用私有 API 实现系统级后台常驻。
/// - 关闭时：功能被禁用，调用无效果，符合 App Store 审核标准。
class TouchBarManager: NSObject {
    
    static let shared = TouchBarManager()
    
    // 标志位，表示是否正在手动关闭 (去掉 private，供 View 读取)
    var isDismissingManually = false
    
    /// 对外暴露的只读属性，用于 UI 层判断是否显示相关按钮
    #if PRIVATE_TOUCHBAR
    let isFeatureAvailable = true
    #else
    let isFeatureAvailable = false
    #endif
    
    // MARK: - 内部状态 (仅在开启时存在)
    #if PRIVATE_TOUCHBAR
    private var systemTouchBar: NSTouchBar?
    #endif

    // MARK: - 公开调用接口 (API 必须保持一致)
    
    /// 切换显示状态
    func toggle() {
        #if PRIVATE_TOUCHBAR
        present()
        #else
        print("🚫 [TouchBarManager] 当前版本未启用私有 TouchBar 功能")
        #endif
    }
    
    /// 强制显示
    func present() {
        #if PRIVATE_TOUCHBAR
        dismiss() // 先清理旧的
        
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.lyricsItem]
        
        // 调用私有 API
        NSTouchBar.presentSystemModal(touchBar: touchBar, placement: 0)
        
        self.systemTouchBar = touchBar
        print("🚀 [TouchBarManager] Touch Bar 已启动 (Private Mode)")
        #endif
    }
    
    /// 销毁隐藏
    func dismiss() {
        #if PRIVATE_TOUCHBAR
        // 1. 标记为手动关闭，防止触发 onDisappear 的自动同步逻辑
        isDismissingManually = true
        
        if let touchBar = systemTouchBar {
            NSTouchBar.dismissSystemModal(touchBar: touchBar)
            systemTouchBar = nil
        }
        
        // 双重保险清理
        let dummy = NSTouchBar()
        NSTouchBar.dismissSystemModal(touchBar: dummy)
        
        // 2. 延迟重置标记 (给 onDisappear 留出反应时间)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isDismissingManually = false
        }
        #endif
    }
}

// MARK: - 扩展与代理

#if PRIVATE_TOUCHBAR

// 1. 代理实现
extension TouchBarManager: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == .lyricsItem {
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = NSHostingView(rootView: TouchBarLyricsView())
            return item
        }
        return nil
    }
}

// 2. 标识符注册
extension NSTouchBarItem.Identifier {
    static let lyricsItem = NSTouchBarItem.Identifier("com.soloist.lyricsItem")
}

// 3. 私有 API 黑魔法
extension NSTouchBar {
    static private func ensureDFRFrameworkLoaded() {
        if let bundle = Bundle(path: "/System/Library/PrivateFrameworks/DFRFoundation.framework") {
            if !bundle.isLoaded { bundle.load() }
        }
    }
    
    static func presentSystemModal(touchBar: NSTouchBar, placement: Int64) {
        ensureDFRFrameworkLoaded()
        let selector = Selector(("presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"))
        if responds(to: selector) {
            let imp = method(for: selector)
            typealias FuncType = @convention(c) (AnyClass, Selector, NSTouchBar, Int64, String?) -> Void
            let funcPtr = unsafeBitCast(imp, to: FuncType.self)
            funcPtr(self, selector, touchBar, placement, nil)
        }
    }
    
    static func dismissSystemModal(touchBar: NSTouchBar) {
        let selector = Selector(("dismissSystemModalTouchBar:"))
        if responds(to: selector) {
            let imp = method(for: selector)
            typealias FuncType = @convention(c) (AnyClass, Selector, NSTouchBar) -> Void
            let funcPtr = unsafeBitCast(imp, to: FuncType.self)
            funcPtr(self, selector, touchBar)
        }
    }
}

// 4. SwiftUI 视图
struct TouchBarLyricsView: View {
    @StateObject private var playerService = AudioPlayerService.shared
    
    var body: some View {
        ZStack {
            Color.black
            Text(playerService.currentLyric.isEmpty ? (playerService.currentSong?.title ?? "Soloist") : playerService.currentLyric)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .id(playerService.currentLyric)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .onDisappear {
            if !TouchBarManager.shared.isDismissingManually && UserDefaults.standard.bool(forKey: "showTouchBarLyrics") {
                
                print("⚠️ 检测到 Touch Bar 被外部关闭，正在同步状态...")
                
                // 1. 修正 UserDefaults
                UserDefaults.standard.set(false, forKey: "showTouchBarLyrics")
                
                // 2. 必须在主线程发送通知，通知 AppDelegate 和 UI 刷新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
                }
            }
        }
    }
}

#endif
