//
//  WebDAVService.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/4/2.
//

import Foundation
import Combine
import GCDWebServer
import UIKit

#if os(iOS)
class WebDAVService: ObservableObject {
    private var webServer: GCDWebServer?
    
    @Published var serverURL: String = ""
    @Published var isRunning: Bool = false
    
    func startServer() {
        guard !isRunning else { return }
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path else { return }
        
        webServer = GCDWebServer()
        
        // 接口 1.5：新增预检接口（返回沙盒中已存在的文件名列表，用于前端秒传比对）
        webServer?.addHandler(forMethod: "GET", path: "/list", request: GCDWebServerRequest.self, processBlock: { _ -> GCDWebServerResponse? in
            var fileNames: [String] = []
            
            // 扫描根目录
            if let docs = try? FileManager.default.contentsOfDirectory(atPath: documentsPath) {
                fileNames.append(contentsOf: docs)
            }
            // 扫描歌词目录
            let lyricsPath = (documentsPath as NSString).appendingPathComponent("Lyrics")
            if let lyrics = try? FileManager.default.contentsOfDirectory(atPath: lyricsPath) {
                fileNames.append(contentsOf: lyrics)
            }
            
            // 过滤隐藏文件
            fileNames = fileNames.filter { !$0.hasPrefix(".") }
            
            let jsonData = (try? JSONSerialization.data(withJSONObject: fileNames, options: [])) ?? Data()
            return GCDWebServerDataResponse(data: jsonData, contentType: "application/json")
        })
        
        // 接口 1：渲染前端 HTML（通过静态常量解耦）
        webServer?.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self, processBlock: { (request: GCDWebServerRequest) -> GCDWebServerResponse? in
            
            // 直接读取隔离文件中的静态字符串
            return GCDWebServerDataResponse(html: WebServerUI.indexHTML)!
            
        })
        
        // 接口 2：处理实际流数据
        webServer?.addHandler(forMethod: "POST", path: "/upload", request: GCDWebServerMultiPartFormRequest.self, processBlock: { [weak self] (request: GCDWebServerRequest) -> GCDWebServerResponse? in
            return self?.handleUpload(request: request, documentsPath: documentsPath)
        })
        
        let options: [String: Any] = [
            GCDWebServerOption_Port: 8080,
            GCDWebServerOption_BindToLocalhost: false
        ]
        
        do {
            try webServer?.start(options: options)
            if let url = webServer?.serverURL {
                DispatchQueue.main.async {
                    self.serverURL = url.absoluteString
                    self.isRunning = true
                    // 开启服务时，禁止屏幕自动休眠
                    UIApplication.shared.isIdleTimerDisabled = true
                }
            }
        } catch {
            print("HTTP 启动失败: \(error.localizedDescription)")
        }
    }
    
    func stopServer() {
        guard isRunning else { return }
        webServer?.stop()
        webServer = nil
        DispatchQueue.main.async {
            self.serverURL = ""
            self.isRunning = false
            // 关闭服务后，恢复屏幕自动休眠
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - 核心业务抽离：IO 处理与路由
    private func handleUpload(request: GCDWebServerRequest, documentsPath: String) -> GCDWebServerResponse? {
        guard let multipartRequest = request as? GCDWebServerMultiPartFormRequest else {
            return GCDWebServerDataResponse(html: "<h3>上传失败：无效的请求</h3>")!
        }
        
        var shouldOverwrite = false
        for arg in multipartRequest.arguments {
            if arg.controlName == "overwrite", arg.string == "true" {
                shouldOverwrite = true
                break
            }
        }
        
        let files = multipartRequest.files
        
        var successCount = 0
        var skipCount = 0
        
        for file in files {
            let tempPath = file.temporaryPath
            // 🚨 核心修复：强制剥离路径前缀，确保安全落盘
            let fileName = (file.fileName as NSString).lastPathComponent
            let fileExtension = (fileName as NSString).pathExtension.lowercased()
            
            var targetPath = (documentsPath as NSString).appendingPathComponent(fileName)
            
            // 路由逻辑：分拣歌词文件
            if fileExtension == "lrc" || fileExtension == "txt" {
                let lyricsDirPath = (documentsPath as NSString).appendingPathComponent("Lyrics")
                if !FileManager.default.fileExists(atPath: lyricsDirPath) {
                    try? FileManager.default.createDirectory(atPath: lyricsDirPath, withIntermediateDirectories: true, attributes: nil)
                }
                targetPath = (lyricsDirPath as NSString).appendingPathComponent(fileName)
            }
            
            // IO 逻辑（此处的 skipCount 为双重兜底，主要依赖前端过滤）
            do {
                if FileManager.default.fileExists(atPath: targetPath) {
                    if shouldOverwrite {
                        try FileManager.default.removeItem(atPath: targetPath)
                        try FileManager.default.moveItem(atPath: tempPath, toPath: targetPath)
                        successCount += 1
                    } else {
                        try FileManager.default.removeItem(atPath: tempPath)
                        skipCount += 1
                        continue
                    }
                } else {
                    try FileManager.default.moveItem(atPath: tempPath, toPath: targetPath)
                    successCount += 1
                }
            } catch {
                print("处理异常 \(fileName): \(error)")
            }
        }
        
        // 核心业务抽离：调用 UI 工厂方法获取动态 HTML
        let resultHtml = WebServerUI.resultHTML(success: successCount, skip: skipCount)
        
        return GCDWebServerDataResponse(html: resultHtml)!
    }
}
#endif
