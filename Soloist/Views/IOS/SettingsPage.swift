//
//  SettingsPage.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/2/8.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsPage: View {
    // 接收主页传进来的 libraryService
    @ObservedObject var libraryService: LocalLibraryService
    let artworkData: Data?
    
    // 本地状态控制导入弹窗
    @State private var showFileImporter = false
    
    var body: some View {
        ZStack {
            IOSBackgroundView(artworkData: artworkData)
            
            NavigationStack {
                Form {
                    Section(header: Text("媒体库管理")) {
                        // 1. 导入按钮
                        Button(action: { showFileImporter = true }) {
                            Label("导入本地音乐", systemImage: "square.and.arrow.down")
                                .foregroundStyle(.primary)
                        }
                        
                        // 2. 刷新按钮
                        Button(action: { libraryService.loadLocalDocuments() }) {
                            Label("刷新媒体库", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.primary)
                        }
                    }
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                    
                    Section(header: Text("关于")) {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("设置")
                // 文件导入器逻辑移到这里
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.audio, UTType(filenameExtension: "lrc") ?? .plainText],
                    allowsMultipleSelection: true
                ) { result in
                    if case .success(let urls) = result {
                        libraryService.importSongs(from: urls)
                    }
                }
            }
        }
    }
}
