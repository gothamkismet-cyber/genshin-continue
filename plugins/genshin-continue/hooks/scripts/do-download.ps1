# genshin-continue 下载进程：解析米哈游官方短链，下载启动器安装包并写日志
$ErrorActionPreference = 'Stop'

$logFile  = Join-Path $env:TEMP 'genshin-continue.log'
$lockFile = Join-Path $env:TEMP 'genshin-continue.lock'
$shortUrl = 'https://mhyurl.cn/Ztkut6sBd'
$fallback = 'https://hyp-webstatic.mihoyo.com/hyp-client/miHoYoLauncher_1.18.exe'

function Log([string]$msg) {
  ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) |
    Out-File -FilePath $logFile -Append -Encoding utf8
}

# 并发保护：上一次下载还在进行则直接跳过
if (Test-Path $lockFile) {
  $oldPidText = Get-Content $lockFile -ErrorAction SilentlyContinue | Select-Object -First 1
  $stillRunning = $false
  try { $stillRunning = [bool](Get-Process -Id ([int]$oldPidText) -ErrorAction SilentlyContinue) } catch {}
  if ($stillRunning) {
    Log "已有下载进行中(PID $oldPidText)，本次触发跳过。"
    exit 0
  }
  Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
$PID | Out-File $lockFile -Encoding ascii

$target = $null
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Log '触发原神下载：开始解析米哈游启动器官方下载地址...'

  # 解析短链的真实目标，便于日志与校验；失败则退回短链直连
  $finalUrl = $null
  try {
    $req = [Net.HttpWebRequest]::Create($shortUrl)
    $req.AllowAutoRedirect = $false
    $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    $resp = $req.GetResponse()
    $finalUrl = $resp.Headers['Location']
    $resp.Close()
  } catch {
    Log ("解析跳转失败({0})，改用官方短链直接下载。" -f $_.Exception.Message)
  }
  if (-not $finalUrl) { $finalUrl = $fallback }
  Log "官方安装包地址：$finalUrl"

  # 服务器支持 Range，用 0-0 请求拿总大小
  $total = 0
  try {
    $r = [Net.HttpWebRequest]::Create($finalUrl)
    $r.AddRange(0, 0)
    $r.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
    $resp2 = $r.GetResponse()
    $cr = $resp2.Headers['Content-Range']
    if ($cr -match '/(\d+)\s*$') { $total = [long]$Matches[1] }
    $resp2.Close()
  } catch {}

  $dlDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
  if (-not (Test-Path $dlDir)) { $dlDir = $env:TEMP }
  $target = Join-Path $dlDir ('MiHoYoLauncher_{0}.exe' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

  Log ("开始下载 → {0}（总大小约 {1:N0} MB）" -f $target, ($total / 1MB))

  $client = New-Object System.Net.WebClient
  $client.Headers.Add('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
  $task = $client.DownloadFileTaskAsync($finalUrl, $target)
  $lastPct = -1
  while (-not $task.IsCompleted) {
    Start-Sleep -Seconds 5
    $done = 0
    try { $done = (Get-Item $target -ErrorAction Stop).Length } catch {}
    if ($total -gt 0) {
      $pct = [int](100 * $done / $total)
      if ($pct -ne $lastPct) {
        $lastPct = $pct
        Log ("进度 {0}%（{1:N0}/{2:N0} MB）" -f $pct, ($done / 1MB), ($total / 1MB))
      }
    } else {
      Log ("已下载 {0:N0} MB" -f ($done / 1MB))
    }
  }
  if ($task.IsFaulted) { throw $task.Exception.InnerException }
  $client.Dispose()
  Log ("下载完成：{0}（{1:N0} MB）。双击安装米哈游启动器，之后在启动器内下载原神即可。" -f $target, ((Get-Item $target).Length / 1MB))
  exit 0
} catch {
  Log ("下载失败：{0}" -f $_.Exception.Message)
  if ($target -and (Test-Path $target)) { Remove-Item $target -Force -ErrorAction SilentlyContinue }
  exit 1
} finally {
  Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
