//
//  TouchBarManager.swift
//  Soloist
//
//  Created by Bole on 2026/1/30.
//

import AppKit
import SwiftUI
import ObjectiveC

class TouchBarManager: NSObject, NSTouchBarDelegate {
    
    // 单例
    static let shared = TouchBarManager()
    
    // 记录当前的 Touch Bar (即使它被系统关了，我们留着也没关系，不占性能)
    private var systemTouchBar: NSTouchBar?
    
    // MARK: - 核心逻辑修改
    
    // 现在的逻辑：不管原来是开是关，只要你点这个，我就强制重开！
    // 这样就完美解决了“状态不同步”导致需要点两下的问题。
    func toggle() {
        present()
    }
    
    // 强制显示
    func present() {
        // 1. 先把旧的清理掉 (无论它现在是否显示)
        // 这步是关键：防止代码以为开着，实际上已经关了
        dismiss()
        
        // 2. 创建一个新的
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [.lyricsItem]
        
        // 3. 申请系统模态显示
        // 0 代表 .appControl (只覆盖中间部分，保留系统功能键)
        NSTouchBar.presentSystemModal(touchBar: touchBar, placement: 0)
        
        self.systemTouchBar = touchBar
        print("🚀 Touch Bar 已强制启动")
    }
    
    // 清理逻辑
    func dismiss() {
        // 如果手里有旧的引用，先关掉它
        if let touchBar = systemTouchBar {
            NSTouchBar.dismissSystemModal(touchBar: touchBar)
            systemTouchBar = nil
        }
        
        // 双重保险：发一个空指令给系统，确保真的退出了
        // 这样可以保证下次 present 绝对是干净的
        let dummy = NSTouchBar()
        NSTouchBar.dismissSystemModal(touchBar: dummy)
    }
    
    // MARK: - NSTouchBarDelegate
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == .lyricsItem {
            let item = NSCustomTouchBarItem(identifier: identifier)
            // 纯净版：没有自定义关闭按钮，直接用系统自带的 X
            item.view = NSHostingView(rootView: TouchBarLyricsView())
            return item
        }
        return nil
    }
}

// 注册 ID
extension NSTouchBarItem.Identifier {
    static let lyricsItem = NSTouchBarItem.Identifier("com.soloist.lyricsItem")
}

// MARK: - 🪄 黑魔法 (适配你的 macOS)
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

// MARK: - SwiftUI 视图 (纯净歌词版)
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
