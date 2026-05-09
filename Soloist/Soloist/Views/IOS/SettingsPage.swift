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
    
    // ✨ 注入全局的网络服务环境变量
    @EnvironmentObject var webDAVService: WebDAVService
    
    let artworkData: Data?
    
    // 本地状态控制导入弹窗
    @State private var showFileImporter = false
    
    var body: some View {
        ZStack {
            IOSBackgroundView(artworkData: artworkData)
            
            NavigationStack {
                Form {
                    // MARK: - ✨ 新增：局域网传输模块
                    Section(header: Text("局域网无线传输")) {
                        if webDAVService.isRunning {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("服务已启动，请在电脑浏览器访问：")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                
                                Text(webDAVService.serverURL)
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                                    // 允许用户长按复制 IP 地址
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                            
                            Button(role: .destructive, action: { webDAVService.stopServer() }) {
                                Label("停止传输服务", systemImage: "stop.circle")
                            }
                        } else {
                            Button(action: { webDAVService.startServer() }) {
                                Label("开启电脑网页导歌", systemImage: "network")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                    
                    // MARK: - 原有媒体库管理
                    Section(header: Text("媒体库管理")) {
                        // 1. 导入按钮 (重命名以区分来源)
                        Button(action: { showFileImporter = true }) {
                            Label("从手机文件 App 导入", systemImage: "folder")
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
                // 文件导入器逻辑
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
