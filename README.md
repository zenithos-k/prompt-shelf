# Prompt Shelf

原生 macOS 菜单栏 Prompt 管理器，用来保存、搜索、编辑、排序和复制常用 Prompt。

- 官网：[prompts.matrdreams.com](https://prompts.matrdreams.com)
- 下载：[Prompt Shelf 1.2.0 DMG](https://prompts.matrdreams.com/downloads/Prompt-Shelf-1.2.0.dmg)

## 已实现功能

- 菜单栏常驻窗口；不显示多余的 Dock 图标
- 新建、编辑、二次确认删除、搜索和一键复制
- 拖动整张卡片（或左侧手柄）调整任意 Prompt 的顺序
- 自动识别内容中的 `{{变量}}`，复制前生成填写和实时预览界面
- 自动跟随系统、浅色、深色三种外观，并提供主界面快捷切换
- 独立设计的蓝紫玻璃应用图标
- 本地 JSON 原子存储、导入、导出、登录时启动、复制后关闭

## 环境要求

- 运行：macOS 13 或更新版本
- 构建：Swift 6 / Xcode 16 或更新版本
- 使用 macOS 26 SDK 构建时启用 Liquid Glass；旧 SDK 或旧系统自动使用原生材质

## 开发

```bash
swift build
swift test
swift run PromptShelf
```

开发时可以直接运行 Swift Package。生成普通菜单栏 `.app`：

```bash
./Scripts/build-app.sh
open "dist/Prompt Shelf.app"
```

生成同时支持 Apple Silicon 和 Intel 的通用应用：

```bash
./Scripts/build-universal-app.sh
```

## 数据

Prompt 默认保存在：

```text
~/Library/Application Support/PromptShelf/prompts.json
```

JSON 文档带有显式 schema 版本。数组顺序就是显示顺序，因此拖动结果会在重启后保留。连续拖动时写盘会合并，最终写入采用原子替换。

## 兼容性与性能

- 使用 `MenuBarExtra` 和原生 SwiftUI 控件，不包含浏览器运行时。
- 列表使用 `LazyVStack`，不会一次创建全部行。
- 变量识别复用单个正则表达式实例。
- 持久化在串行 utility 队列执行，并在窗口关闭前同步刷新。
- Liquid Glass 同时受编译期 SDK 判断和 `#available(macOS 26, *)` 保护。
- 应用仅使用本地数据，不发起网络请求。

## 官网

`Website/site` 是无框架、无外部依赖的静态单页，使用 Cloudflare Workers Static Assets 部署。下载包不会提交到 Git 仓库；发布前将 DMG 放进 `Website/site/downloads/`，然后执行：

```bash
cd Website
wrangler deploy
```
