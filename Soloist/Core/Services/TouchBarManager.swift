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
        dismiss()
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.lyricsItem]
        
        // 调用私有 API
        NSTouchBar.presentSystemModal(touchBar: touchBar, placement: 0)
        
        self.systemTouchBar = touchBar
        print("🚀 [TouchBarManager] Touch Bar 已强制启动 (Private Mode)")
        #endif
    }
    
    /// 销毁隐藏
    func dismiss() {
        #if PRIVATE_TOUCHBAR
        if let touchBar = systemTouchBar {
            NSTouchBar.dismissSystemModal(touchBar: touchBar)
            systemTouchBar = nil
        }
        // 双重保险清理
        let dummy = NSTouchBar()
        NSTouchBar.dismissSystemModal(touchBar: dummy)
        #endif
    }
}

// MARK: - 扩展与代理 (全部关进笼子)

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
    }
}

#endif
