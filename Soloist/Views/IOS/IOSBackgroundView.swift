//
//  IOSBackgroundView.swift
//  Soloist
//
//  Created by Bole on 2026/2/7.
//

import SwiftUI

struct IOSBackgroundView: View {
    let artworkData: Data?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                // 方案 A: 有封面 -> 显示模糊的大图
                if let data = artworkData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .drawingGroup() // Metal 加速渲染，防止卡顿
                        .blur(radius: 80)
                }
                // 方案 B: 无封面 -> 静态极光背景
                else {
                    ZStack {
                        // 1. 底色：纯黑 (衬托光感)
                        Color.black
                        
                        // 2. 左上角光斑：使用青色 (Cyan)
                        Circle()
                            .fill(Color.cyan.opacity(0.6))
                            .frame(width: 500, height: 500)
                            .blur(radius: 120)
                            .offset(x: -150, y: -150)
                        
                        // 3. 右下角光斑：使用粉色 (Pink)
                        Circle()
                            .fill(Color.pink.opacity(0.6))
                            .frame(width: 400, height: 400)
                            .blur(radius: 100)
                            .offset(x: 100, y: 150)
                        
                        // 4. 深蓝氛围
                        Circle()
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: 600, height: 600)
                            .blur(radius: 150)
                    }
                    // 确保背景填满整个屏幕区域
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .drawingGroup()
                }
            }
        }
        .ignoresSafeArea()
        // 统一叠加一层黑色遮罩，确保前景文字清晰可见
        .overlay(Color.black.opacity(0.3))
    }
}
