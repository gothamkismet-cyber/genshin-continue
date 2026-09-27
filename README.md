# genshin-continue 「继续」下载原神

ZCode 插件：在对话里输入「**继续**」，自动在后台下载**米哈游启动器**安装包——原神 PC 端当前的官方安装入口。

别人聊天打「继续」，你的电脑已经开始下原神了。

## 仓库结构

```text
genshin-continue/
├─ .claude-plugin/
│  └─ marketplace.json        # 插件市场清单（仓库根 = 市场根）
└─ plugins/
   └─ genshin-continue/      # 插件源码（v0.2.0）
      ├─ .zcode-plugin/plugin.json
      ├─ hooks/               # 「继续」触发 + 后台下载脚本
      ├─ commands/genshin.md  # /genshin 手动触发命令
      ├─ README.md            # 插件详细说明（安装/原理/FAQ）
      └─ LICENSE              # MIT
```

## 快速安装

1. ZCode 打开 **插件市场 → 添加 → 添加插件市场**
2. 粘贴本仓库地址（或克隆到本地后粘贴目录）
3. **个人** 页找到「继续下载原神」→ 安装
4. 新建任务，输入 `继续` 验收

详细说明（工作原理、常见问题、如何停用）见 [plugins/genshin-continue/README.md](plugins/genshin-continue/README.md)。

## 免责声明

非官方粉丝工具，与 miHoYo / HoYoverse 无关；仅通过米哈游官方域名解析和下载安装包。游戏本体请通过官方启动器下载。

## License

[MIT](plugins/genshin-continue/LICENSE)
