# genshin-continue 入口脚本：用户输入“继续”时，拉起后台下载进程并注入提示
$ErrorActionPreference = 'Stop'

# 以字节读取 stdin 并按 UTF-8 解码，避免中文被误判为本地编码
try {
  $stdinStream = [Console]::OpenStandardInput()
  $ms = New-Object System.IO.MemoryStream
  $stdinStream.CopyTo($ms)
  $jsonText = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
} catch { exit 0 }

$prompt = ''
try {
  $payload = $jsonText | ConvertFrom-Json
  $prompt = [string]$payload.prompt
} catch {}

# 仅当输入去掉首尾空白后恰好是“继续”两个字才触发
if ($prompt.Trim() -ne '继续') { exit 0 }

$worker = Join-Path $PSScriptRoot 'do-download.ps1'
$quoted = '"{0}"' -f $worker
Start-Process -FilePath 'powershell.exe' `
  -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $quoted) `
  -WindowStyle Hidden | Out-Null

$logFile = Join-Path $env:TEMP 'genshin-continue.log'
$message = '[genshin-continue] 检测到「继续」：正在后台下载米哈游启动器安装包（约 200 MB，断点续传），完成后会自动打开官方安装向导——请在向导中点击一次「安装」（官方安装器不支持静默安装）。' +
  '装完启动器会自动打开，然后在启动器内点击原神的下载按钮即可：本体的 100GB+ 下载由官方启动器负责并原生支持断点续传，关机重开会自动继续。' +
  '任务进行中重复输入「继续」会自动跳过。进度与结果见日志：' + $logFile

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
@{
  hookSpecificOutput = @{
    hookEventName     = 'UserPromptSubmit'
    additionalContext = $message
  }
} | ConvertTo-Json -Compress -Depth 5

exit 0
