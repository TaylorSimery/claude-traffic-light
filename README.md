# Claude Traffic Light

**中文** · [English](README.en.md)

一个浮窗式的磨砂黑交通信号灯，实时映射 macOS 上 [Claude Code](https://claude.com/claude-code) 的运行状态。

<p align="center">
  <img src="docs/assets/icon.png" width="180" alt="Claude Traffic Light" />
</p>

<p align="center">
  <a href="https://taylorsimery.github.io/claude-traffic-light/">网站</a>
  ·
  <a href="https://github.com/TaylorSimery/claude-traffic-light/releases">下载</a>
  ·
  <a href="#快速开始">快速开始</a>
</p>

## 为什么需要它

Claude Code 跑在终端里，你切走窗口就看不到它在做什么。Claude Traffic Light 读取它的会话日志，用一个能瞄一眼就懂的信号告诉你状态:

- **黄灯** — Claude 正在思考、流式输出或调用工具。
- **绿灯** — 上一轮已经干净结束,可以回来看了。
- **红灯** — 工具调用在等你确认,或运行出错,或进程退出。

## 特性

- 原生 SwiftUI 组件,没有 Electron、没有 Python、没有辅助脚本。
- 磨砂黑面板,浮在所有窗口和所有 Space 之上,包括全屏应用。
- 任意位置拖动,右键退出。
- 没有菜单栏图标,没有 Dock 图标 — 以 `LSUIElement` 后台应用形式运行。
- 直接读取 `~/.claude/projects/**/*.jsonl`,无网络、无埋点。
- Universal 二进制,本地签名,Apple Silicon 与 Intel 均可,macOS 13 起。

## 快速开始

### 下载预编译版本

1. 从 [最新 Release](https://github.com/TaylorSimery/claude-traffic-light/releases) 下载 `ClaudeTrafficLight.zip`。
2. 解压后把 `ClaudeTrafficLight.app` 拖到 `/Applications`。
3. 应用是 ad-hoc 签名,首次启动需要右键 → **打开**,或者执行一次:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ClaudeTrafficLight.app
   ```
4. 启动后,组件会出现在主屏幕右上角。

### 从源码构建

需要 Xcode 15+ 与 macOS 13+。

```bash
git clone https://github.com/TaylorSimery/claude-traffic-light.git
cd claude-traffic-light
open ClaudeTrafficLight.xcodeproj
```

按 **⌘R** 运行,或者构建 Release 版:

```bash
xcodebuild -project ClaudeTrafficLight.xcodeproj \
           -scheme ClaudeTrafficLight \
           -configuration Release \
           -derivedDataPath build clean build
open build/Build/Products/Release/ClaudeTrafficLight.app
```

## 状态如何识别

Claude Code 在工作时,会按行写 JSON 到 `~/.claude/projects/<project>/<session>.jsonl`。组件每秒轮询最新文件,综合三个信号:

- `pgrep claude` — CLI 进程是否还活着?
- 最后一条消息的 `stop_reason` 与 `content`。
- 文件最后一次修改距今多久。

据此选出 `running`、`success`、`error` 之一。完整规则在 `ClaudeMonitor.swift`,单文件、好改。

## 项目结构

```
ClaudeTrafficLight/
  ClaudeTrafficLightApp.swift    应用入口与窗口装配
  FloatingPanel.swift            无边框、置顶的 NSPanel
  TrafficLightView.swift         SwiftUI 信号灯与磨砂黑背景
  ClaudeMonitor.swift            轮询 Claude Code 会话日志
  Assets.xcassets/AppIcon        多分辨率应用图标
  Info.plist                     LSUIElement 与 bundle 元数据
ClaudeTrafficLight.xcodeproj/    纯 Xcode 工程,无 SPM 无 CocoaPods
docs/                            GitHub Pages 落地页
```

## 许可证

MIT。详见 [LICENSE](LICENSE)。

## 致谢

基于 SwiftUI 构建。图标与视觉语言为 [Anthropic Claude Code](https://claude.com/claude-code) 设计。
