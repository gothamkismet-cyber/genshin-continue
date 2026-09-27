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
$message = '[genshin-continue] 检测到输入「继续」，已在后台开始下载米哈游启动器（原神 PC 端官方入口，安装包约 200 MB）。' +
  "安装包将保存到「下载」文件夹；实时进度与结果见日志：$logFile。" +
  '下载进行中时再次输入「继续」会自动跳过，不会重复下载。'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
@{
  hookSpecificOutput = @{
    hookEventName     = 'UserPromptSubmit'
    additionalContext = $message
  }
} | ConvertTo-Json -Compress -Depth 5

exit 0
