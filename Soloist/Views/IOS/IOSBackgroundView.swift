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
        GeometryReader { geo in
            Group {
                if let data = artworkData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .drawingGroup() // Metal 加速
                        .blur(radius: 60)
                        .overlay(Color.black.opacity(0.3))
                } else {
                    // 默认渐变背景
                    ZStack {
                        Color(uiColor: .systemBackground)
                        Circle().fill(Color.blue.opacity(0.2))
                            .frame(width: 300, height: 300).blur(radius: 80).offset(x: -100, y: -150)
                        Circle().fill(Color.purple.opacity(0.2))
                            .frame(width: 250, height: 250).blur(radius: 60).offset(x: 100, y: 100)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
