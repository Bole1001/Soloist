//
//  LyricsView.swift
//  SoloistMac
//
//  Created by Bole on 2026/5/10.
//

import SwiftUI

struct LyricsView: View {
    @State var guarder = PhantomGuard.shared
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            if let index = guarder.currentLineIndex, index < guarder.currentLyrics.count {
                Text(guarder.currentLyrics[index].text)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .id("lyric_\(index)")
                
                if index + 1 < guarder.currentLyrics.count {
                    Text(guarder.currentLyrics[index + 1].text)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .shadow(color: .black.opacity(0.5), radius: 5)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .opacity(0.8)
                        .id("next_\(index)")
                }
            }
        }
        .frame(width: 800, height: 180)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: guarder.currentLineIndex)
    }
}
