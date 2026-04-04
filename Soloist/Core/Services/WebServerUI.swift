//
//  WebServerUI.swift
//  Soloist-iOS
//
//  Created by Bole on 2026/4/4.
//

import Foundation

/// 专门用于存放局域网网页端 UI 的静态资源
struct WebServerUI {
    
    static let indexHTML = """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Soloist 媒体库同步</title>
    <style>
    :root {
        --bg-grad: linear-gradient(135deg, #e0eafc 0%, #cfdef3 100%);
        --card-bg: rgba(255, 255, 255, 0.75);
        --text: #1d1d1f; --sub: #86868b;
        --primary: #007aff; --primary-hover: #005bb5;
        --border: rgba(0, 0, 0, 0.1);
        --blur: blur(24px);
    }
    @media (prefers-color-scheme: dark) {
        :root {
            --bg-grad: linear-gradient(135deg, #0f2027 0%, #203a43 50%, #2c5364 100%);
            --card-bg: rgba(30, 30, 32, 0.65);
            --text: #f5f5f7; --sub: #a1a1a6;
            --primary: #0a84ff; --primary-hover: #007aff;
            --border: rgba(255, 255, 255, 0.15);
        }
    }
    
    * { box-sizing: border-box; -webkit-font-smoothing: antialiased; }
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg-grad); background-attachment: fixed; display: flex; align-items: center; justify-content: center; min-height: 100vh; overflow: hidden; }
    
    .card { width: 90%; max-width: 480px; background: var(--card-bg); backdrop-filter: var(--blur); -webkit-backdrop-filter: var(--blur); border: 1px solid var(--border); border-radius: 24px; padding: 32px; box-shadow: 0 24px 48px rgba(0,0,0,0.12), 0 8px 16px rgba(0,0,0,0.08); transition: transform 0.3s ease; }
    
    h1 { margin: 0 0 8px; font-size: 24px; font-weight: 700; color: var(--text); letter-spacing: -0.5px; }
    .subtitle { margin: 0 0 24px; font-size: 14px; color: var(--sub); }
    
    .selector-area { background: rgba(0, 122, 255, 0.08); border: 2px dashed rgba(0, 122, 255, 0.3); border-radius: 16px; padding: 28px 20px; text-align: center; cursor: pointer; transition: all 0.2s cubic-bezier(0.2, 0.8, 0.2, 1); }
    .selector-area:hover { background: rgba(0, 122, 255, 0.12); border-color: var(--primary); transform: translateY(-2px); }
    .selector-text { font-size: 16px; font-weight: 600; color: var(--primary); margin: 0; }
    .selector-hint { font-size: 12px; color: var(--sub); margin-top: 6px; }
    .hidden { display: none; }
    
    .option { margin: 20px 0; padding: 12px 16px; background: rgba(0,0,0,0.03); border-radius: 12px; display: flex; align-items: center; font-size: 14px; color: var(--text); cursor: pointer; }
    @media (prefers-color-scheme: dark) { .option { background: rgba(255,255,255,0.05); } }
    .option input { margin-right: 10px; width: 16px; height: 16px; accent-color: var(--primary); }
    
    button { width: 100%; padding: 16px; border: none; border-radius: 14px; background: var(--primary); color: #fff; font-size: 16px; font-weight: 600; letter-spacing: 0.5px; cursor: pointer; transition: all 0.2s ease; box-shadow: 0 8px 16px rgba(0, 122, 255, 0.2); }
    button:hover { background: var(--primary-hover); transform: translateY(-1px); box-shadow: 0 10px 20px rgba(0, 122, 255, 0.3); }
    button:active { transform: scale(0.98); }
    button:disabled { background: var(--sub); box-shadow: none; cursor: not-allowed; opacity: 0.7; transform: none; }
    
    .list { margin-top: 20px; max-height: 180px; overflow-y: auto; border-radius: 12px; }
    .list::-webkit-scrollbar { width: 6px; }
    .list::-webkit-scrollbar-track { background: transparent; }
    .list::-webkit-scrollbar-thumb { background: rgba(134, 134, 139, 0.4); border-radius: 3px; }
    .item { display: flex; justify-content: space-between; padding: 10px 12px; font-size: 13px; color: var(--text); border-bottom: 1px solid var(--border); }
    .item:last-child { border-bottom: none; }
    .size { color: var(--sub); font-variant-numeric: tabular-nums; }
    
    .progress-container { margin-top: 20px; display: none; }
    .progress-track { height: 8px; background: rgba(0,0,0,0.05); border-radius: 4px; overflow: hidden; box-shadow: inset 0 1px 2px rgba(0,0,0,0.1); }
    @media (prefers-color-scheme: dark) { .progress-track { background: rgba(255,255,255,0.1); } }
    .progress-bar { height: 100%; width: 0%; background: var(--primary); background-image: linear-gradient(45deg, rgba(255,255,255,0.15) 25%, transparent 25%, transparent 50%, rgba(255,255,255,0.15) 50%, rgba(255,255,255,0.15) 75%, transparent 75%, transparent); background-size: 1rem 1rem; transition: width 0.3s ease; animation: progress-stripes 1s linear infinite; }
    @keyframes progress-stripes { from { background-position: 1rem 0; } to { background-position: 0 0; } }
    
    .meta { margin-top: 10px; font-size: 12px; color: var(--sub); display: flex; justify-content: space-between; font-variant-numeric: tabular-nums; }
    #log { margin-top: 12px; font-size: 13px; color: var(--sub); text-align: center; font-weight: 500; }
    </style>
    </head>
    <body>
    
    <div class="card">
      <h1>Soloist 同步</h1>
      <p class="subtitle">局域网媒体同步</p>
    
      <div id="selector" class="selector-area" onclick="document.getElementById('fileInput').click()">
        <p class="selector-text">点击选择音乐文件夹</p>
      </div>
      <input id="fileInput" class="hidden" type="file" multiple webkitdirectory directory>
    
      <label class="option">
        <input type="checkbox" id="overwrite">
        <span>覆盖手机端同名文件</span>
      </label>
    
      <button id="submitBtn" onclick="startSync()">开始同步</button>
    
      <div class="list" id="list"></div>
    
      <div class="progress-container" id="progressContainer">
        <div class="progress-track"><div class="progress-bar" id="bar"></div></div>
        <div class="meta"><span id="count"></span><span id="speed"></span></div>
      </div>
      
      <div id="log"></div>
    </div>
    
    <script>
    const input = document.getElementById('fileInput');
    const list = document.getElementById('list');
    const countEl = document.getElementById('count');
    
    function formatSize(size){
      if(size === 0) return '0 B';
      const units = ['B','KB','MB','GB']; 
      let i = 0;
      while(size >= 1024 && i < units.length - 1){ size /= 1024; i++; }
      return size.toFixed(1) + ' ' + units[i];
    }
    
    function renderList(files){
      let total = 0;
      let htmlString = '';
      const MAX_DISPLAY = 50;
      
      for(let i = 0; i < files.length; i++){
        total += files[i].size;
        if(i < MAX_DISPLAY){
          const pureName = files[i].name.split('/').pop();
          htmlString += `<div class="item"><span>${pureName}</span><span class="size">${formatSize(files[i].size)}</span></div>`;
        }
      }
      
      if(files.length > MAX_DISPLAY) {
          htmlString += `<div class="item" style="justify-content:center; color:var(--sub); border-bottom:none;">...以及其他 ${files.length - MAX_DISPLAY} 个文件</div>`;
      }
      
      list.innerHTML = htmlString;
      countEl.textContent = `${files.length} 项 · ${formatSize(total)}`;
    }
    
    input.onchange = () => {
        if(input.files.length > 0) {
            renderList(input.files);
            document.getElementById('selector').style.padding = '14px';
        }
    };
    
    async function startSync(){
      const overwrite = document.getElementById('overwrite').checked;
      const btn = document.getElementById('submitBtn');
      const log = document.getElementById('log');
      const bar = document.getElementById('bar');
      const progContainer = document.getElementById('progressContainer');
      const speedEl = document.getElementById('speed');
    
      if(input.files.length === 0) return alert('请先选择文件夹');
    
      btn.disabled = true;
      log.innerHTML = '<span style="color:var(--primary)">正在比对设备指纹...</span>';
    
      try{
        const res = await fetch('/list');
        const existing = new Set(await res.json());
    
        const formData = new FormData();
        let upload = 0, skip = 0, totalSize = 0;
    
        for(const file of input.files){
          const pureFileName = file.name.split('/').pop();
          if(pureFileName.startsWith('.')) continue;
          
          if(!overwrite && existing.has(pureFileName)) {
              skip++;
          } else {
              formData.append('files', file);
              upload++;
              totalSize += file.size;
          }
        }
    
        if(upload === 0){
          log.innerHTML = `<span style="color:#28a745">已自动跳过 ${skip} 个已存在的文件</span>`;
          btn.disabled = false;
          return;
        }
    
        if(overwrite) formData.append('overwrite','true');
    
        log.textContent = `准备传输 ${upload} 个文件 (跳过 ${skip} 个)`;
        progContainer.style.display = 'block';
        list.style.display = 'none';
    
        const xhr = new XMLHttpRequest();
        xhr.open('POST','/upload');
        xhr.timeout = 300000; 
    
        let startTime = Date.now();
    
        xhr.upload.onprogress = e => {
          if(e.lengthComputable){
            const percent = (e.loaded / e.total) * 100;
            bar.style.width = percent + '%';
    
            const elapsed = (Date.now() - startTime) / 1000;
            if(elapsed > 0.5) {
                const speed = e.loaded / elapsed;
                speedEl.textContent = formatSize(speed) + '/s';
            }
          }
        };
    
        xhr.onload = () => {
          if (xhr.status === 200) {
              log.textContent = '传输完成，正在校验落盘...';
              speedEl.textContent = '完成';
              bar.style.background = '#28a745';
              setTimeout(() => {
                document.open(); document.write(xhr.responseText); document.close();
              }, 400);
          } else {
              log.innerHTML = `<span style="color:#dc3545">服务器错误: ${xhr.status}</span>`;
              btn.disabled = false;
          }
        };
    
        xhr.ontimeout = () => { log.innerHTML = '<span style="color:#dc3545">连接超时，请检查同一 Wi-Fi</span>'; btn.disabled = false; };
        xhr.onerror = () => { log.innerHTML = '<span style="color:#dc3545">网络中断，请保持 App 在前台常亮</span>'; btn.disabled = false; };
    
        xhr.send(formData);
    
      }catch(e){
        log.innerHTML = `<span style="color:#dc3545">预检错误: ${e}</span>`;
        btn.disabled = false;
      }
    }
    </script>
    </body>
    </html>
    """
    
    static func resultHTML(success: Int, skip: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>同步结果</title>
        <style>
        :root {
            --bg-grad: linear-gradient(135deg, #e0eafc 0%, #cfdef3 100%);
            --card-bg: rgba(255, 255, 255, 0.75);
            --text: #1d1d1f; --sub: #86868b;
            --primary: #007aff;
            --blur: blur(24px);
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --bg-grad: linear-gradient(135deg, #0f2027 0%, #203a43 50%, #2c5364 100%);
                --card-bg: rgba(30, 30, 32, 0.65);
                --text: #f5f5f7; --sub: #a1a1a6;
            }
        }
        body { margin: 0; font-family: -apple-system, sans-serif; background: var(--bg-grad); display: flex; align-items: center; justify-content: center; height: 100vh; }
        .card { width: 90%; max-width: 400px; background: var(--card-bg); backdrop-filter: var(--blur); -webkit-backdrop-filter: var(--blur); border-radius: 24px; padding: 40px; text-align: center; box-shadow: 0 24px 48px rgba(0,0,0,0.12); }
        h2 { color: #28a745; margin: 0 0 16px; }
        p { margin: 8px 0; color: var(--text); }
        .skip { color: var(--sub); font-size: 14px; }
        a { display: inline-block; margin-top: 24px; padding: 14px 28px; background: var(--primary); color: #fff; text-decoration: none; border-radius: 12px; font-weight: 600; }
        </style>
        </head>
        <body>
            <div class="card">
                <h2>同步落盘完成</h2>
                <p>成功新增/覆盖: <strong>\(success)</strong> 个文件</p>
                <p class="skip">跳过: <strong>\(skip)</strong> 个文件</p>
                <a href="/">返回继续</a>
            </div>
        </body>
        </html>
        """
    }
}
