---
description: 手动触发：下载并安装米哈游启动器，准备下载原神
---

帮用户手动触发一次 genshin-continue 插件的完整流程，按以下步骤执行：

1. 用 Bash 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PLUGIN_ROOT/hooks/scripts/do-download.ps1"`
   如果 `$CLAUDE_PLUGIN_ROOT` 没有被自动展开，就先在本插件安装目录下找到 `hooks/scripts/do-download.ps1` 再运行。
2. 脚本会依次完成：解析官方短链 → 下载约 200 MB 安装包（断点续传，网络快时十几秒）→ 自动打开官方安装向导。向导需要用户点击一次「安装」（官方安装器不支持静默安装），之后脚本会自动检测安装结果并打开启动器。
3. 告诉用户：向导弹出后点一次「安装」即可；原神本体（100GB+）在启动器界面里点原神的下载按钮，由官方启动器完成下载与断点续传，关机重开会自动继续。
4. 脚本结束后用 `Get-Content "$env:TEMP\genshin-continue.log" -Tail 8` 读取日志，把状态汇报给用户。
5. 只执行一次，不要因为耗时而重复触发；如果日志显示"已有任务进行中"，如实告知用户即可。
