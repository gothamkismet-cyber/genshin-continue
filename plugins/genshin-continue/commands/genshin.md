---
description: 手动触发下载米哈游启动器（原神 PC 端官方入口）
---

帮用户手动触发一次 genshin-continue 插件的下载，按以下步骤执行：

1. 用 Bash 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PLUGIN_ROOT/hooks/scripts/do-download.ps1"`
   如果 `$CLAUDE_PLUGIN_ROOT` 没有被自动展开，就先在本插件安装目录下找到 `hooks/scripts/do-download.ps1` 再运行。
2. 脚本会解析米哈游官方短链并下载约 200 MB 的安装包，网络快时十几秒，慢时可能几分钟；请耐心等待命令结束。
3. 结束后用 `Get-Content "$env:TEMP\genshin-continue.log" -Tail 5` 读取日志最后几行，把下载状态（进度 / 完成路径 / 失败原因）汇报给用户。
4. 只执行一次，不要因为耗时而重复触发；如果日志显示“已有下载进行中”，如实告知用户即可。
