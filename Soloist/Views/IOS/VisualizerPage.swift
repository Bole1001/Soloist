//
//  VisualizerPage.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import SwiftUI

struct VisualizerPage: View {
    // 接收封面数据，为了以后做背景模糊或颜色提取
    let artworkData: Data?
    
    var body: some View {
        ZStack {
            // 1. 背景：深色沉浸感
            Color.black.ignoresSafeArea()
            
            // 如果有封面，可以搞个极淡的背景
            if let data = artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.2)
                    .blur(radius: 50)
            }
            
            // 2. 占位内容
            VStack(spacing: 30) {
                // 酷炫的图标组合
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 150, height: 150)
                        .opacity(0.5)
                    
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative.reversing) // iOS 17+ 呼吸动画
                }
                
                VStack(spacing: 8) {
                    Text("沉浸视效 & 时光机")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    Text("Visualizer & Retro Pod")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                
                Text("功能开发中...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 20)
            }
        }
    }
}

#Preview {
    VisualizerPage(artworkData: nil)
}
