# genshin-continue 下载进程：下载启动器安装包（断点续传）→ 打开官方安装向导 → 检测安装 → 拉起 HoYoPlay
# 游戏本体由 HoYoPlay 原生下载（官方支持断点续传，关机重开可继续）
$ErrorActionPreference = 'Stop'

$logFile   = Join-Path $env:TEMP 'genshin-continue.log'
$lockFile  = Join-Path $env:TEMP 'genshin-continue.lock'
$stateFile = Join-Path $env:TEMP 'genshin-continue.state'
$shortUrl  = 'https://mhyurl.cn/Ztkut6sBd'
$fallback  = 'https://hyp-webstatic.mihoyo.com/hyp-client/miHoYoLauncher_1.18.exe'
$regPaths  = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Log([string]$msg) {
  ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg) |
    Out-File -FilePath $logFile -Append -Encoding utf8
}

# 并发保护：上一次还在跑则跳过
if (Test-Path $lockFile) {
  $oldPidText = Get-Content $lockFile -ErrorAction SilentlyContinue | Select-Object -First 1
  $stillRunning = $false
  try { $stillRunning = [bool](Get-Process -Id ([int]$oldPidText) -ErrorAction SilentlyContinue) } catch {}
  if ($stillRunning) {
    Log "已有任务进行中(PID $oldPidText)，本次触发跳过。"
    exit 0
  }
  Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
$PID | Out-File $lockFile -Encoding ascii

$installed = $false
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  # 0) 已装 HoYoPlay 则直接拉起
  $installDir = $null
  $existing = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'HoYoPlay|miHoYo Launcher' -and $_.InstallLocation } |
    Select-Object -First 1
  if ($existing) { $installDir = $existing.InstallLocation }
  foreach ($p in @("$env:ProgramFiles\miHoYo Launcher", "${env:ProgramFiles(x86)}\miHoYo Launcher")) {
    if (-not $installDir -and (Test-Path (Join-Path $p 'HoYoPlay.exe'))) { $installDir = $p }
  }
  if ($installDir -and (Test-Path (Join-Path $installDir 'HoYoPlay.exe'))) {
    Log "检测到已安装米哈游启动器：$installDir"
    $installed = $true
  }

  # 1) 下载安装包（固定文件名 + Range 断点续传）
  if (-not $installed) {
    Log '开始解析米哈游启动器官方下载地址...'
    $finalUrl = $null
    try {
      $req = [Net.HttpWebRequest]::Create($shortUrl)
      $req.AllowAutoRedirect = $false
      $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      $resp = $req.GetResponse(); $finalUrl = $resp.Headers['Location']; $resp.Close()
    } catch { Log ("解析跳转失败({0})，改用回退地址。" -f $_.Exception.Message) }
    if (-not $finalUrl) { $finalUrl = $fallback }
    Log "官方安装包地址：$finalUrl"

    $total = 0
    try {
      $r = [Net.HttpWebRequest]::Create($finalUrl)
      $r.AddRange(0, 0); $r.UserAgent = 'Mozilla/5.0'
      $resp2 = $r.GetResponse()
      $cr = $resp2.Headers['Content-Range']
      if ($cr -match '/(\d+)\s*$') { $total = [long]$Matches[1] }
      $resp2.Close()
    } catch {}

    $dlDir = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    if (-not (Test-Path $dlDir)) { $dlDir = $env:TEMP }
    $target = Join-Path $dlDir 'MiHoYoLauncher_latest.exe'

    # 状态文件里的 URL 变了说明官方换了包，旧进度作废
    $state = $null
    try { $state = Get-Content $stateFile -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
    if ($state -and $state.url -ne $finalUrl) {
      Remove-Item $target -Force -ErrorAction SilentlyContinue
      Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
      $state = $null
    }
    @{ url = $finalUrl; total = $total } | ConvertTo-Json -Compress |
      Set-Content $stateFile -Encoding utf8

    $have = 0
    if (Test-Path $target) { $have = (Get-Item $target).Length }
    if ($total -gt 0 -and $have -gt $total) { $have = 0 }  # 异常残留，重来

    if ($total -gt 0 -and $have -eq $total) {
      Log ("安装包已就绪（{0:N0} MB），跳过下载。" -f ($total / 1MB))
    } else {
      if ($have -gt 0) { Log ("检测到未完成下载，从 {0:N0} MB 处续传。" -f ($have / 1MB)) }
      else { Log ("开始下载 → {0}（总大小约 {1:N0} MB）" -f $target, ($total / 1MB)) }

      $fs = [IO.File]::Open($target, [IO.FileMode]::Append, [IO.FileAccess]::Write)
      try {
        $req2 = [Net.HttpWebRequest]::Create($finalUrl)
        $req2.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        if ($have -gt 0) { $req2.AddRange($have) }
        $resp3 = $req2.GetResponse()
        if ($have -gt 0 -and $resp3.StatusCode -ne [Net.HttpStatusCode]::PartialContent) {
          # 服务器不支持续传，推倒重来
          Log '服务器不支持断点续传，改为整包重新下载。'
          $fs.Close(); $fs = $null
          $fs = [IO.File]::Open($target, [IO.FileMode]::Create, [IO.FileAccess]::Write)
          $have = 0
        }
        $stream = $resp3.GetResponseStream()
        $buf = New-Object byte[] (1MB)
        $lastLog = Get-Date
        while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
          $fs.Write($buf, 0, $n)
          if (((Get-Date) - $lastLog).TotalSeconds -ge 10) {
            $lastLog = Get-Date
            $done = (Get-Item $target).Length
            if ($total -gt 0) {
              Log ("下载进度 {0}%（{1:N0}/{2:N0} MB）" -f [int](100 * $done / $total), ($done / 1MB), ($total / 1MB))
            } else {
              Log ("已下载 {0:N0} MB" -f ($done / 1MB))
            }
          }
        }
        $stream.Close(); $resp3.Close()
      } finally { if ($fs) { $fs.Dispose() } }
      Log ("安装包下载完成：{0}（{1:N0} MB）" -f $target, ((Get-Item $target).Length / 1MB))
    }

    # 2) 打开官方安装向导（实测该安装器无静默开关，需人工点一次“安装”），等待装完
    Log '已打开米哈游启动器安装向导，请在向导中点击“安装”（默认路径即可）。'
    Log '等待安装完成（向导关闭后本脚本会自动检测并接管）...'
    Start-Process -FilePath $target -Wait
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
      $hit = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'HoYoPlay|miHoYo Launcher' -and $_.InstallLocation } |
        Select-Object -First 1
      if ($hit) { $installDir = $hit.InstallLocation; break }
      Start-Sleep -Seconds 3
    }
    if (-not $installDir) {
      foreach ($p in @("$env:ProgramFiles\miHoYo Launcher", "${env:ProgramFiles(x86)}\miHoYo Launcher")) {
        if (Test-Path (Join-Path $p 'HoYoPlay.exe')) { $installDir = $p; break }
      }
    }
    if ($installDir) {
      Log "米哈游启动器安装完成：$installDir"
      $installed = $true
    } else {
      Log '向导已关闭但未检测到安装。下次输入「继续」可重新打开向导，安装包无需重新下载。'
      exit 0
    }
  }

  # 3) 拉起 HoYoPlay（游戏本体在启动器里下载，官方原生断点续传）
  if ($installed) {
    $exe = Join-Path $installDir 'HoYoPlay.exe'
    if (Get-Process -Name HoYoPlay -ErrorAction SilentlyContinue) {
      Log '米哈游启动器已在运行。'
    } else {
      Log "启动米哈游启动器：$exe"
      Start-Process -FilePath $exe | Out-Null
    }
    Log '完成。请在启动器中找到原神并点击下载；本体的 100GB+ 下载由启动器负责，支持断点续传，关机重开后自动继续。'
  }
  exit 0
} catch {
  Log ("失败：{0}" -f $_.Exception.Message)
  Log '未完成的部分会在下次输入「继续」时自动续传/重试。'
  exit 1
} finally {
  Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
