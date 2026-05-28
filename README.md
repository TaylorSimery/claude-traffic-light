# Claude Traffic Light

把 Claude Code 的工作状态放到菜单栏里。红灯提醒你需要回到会话，黄灯表示 Claude 正在处理，绿灯表示已经完成，可以继续下一步。

[Website](https://taylorsimery.github.io/claude-traffic-light/) · [Releases](https://github.com/TaylorSimery/claude-traffic-light/releases) · [Issues](https://github.com/TaylorSimery/claude-traffic-light/issues)

## Why

Claude Code 很适合长时间跑任务，但用户经常需要在 IDE、终端、浏览器和文档之间切换。Claude Traffic Light 用一个常驻、可扫视的状态灯解决这个问题：不需要反复切回窗口确认 Claude 是否完成，也不会错过需要用户选择或输入的中断状态。

## Highlights

- **实时状态指示**：通过 Claude Code hooks 监听会话事件，并映射为红、黄、绿三种状态。
- **常驻菜单栏**：悬浮窗口与系统托盘入口并存，适合多窗口工作流。
- **双显示模式**：支持经典三灯模式和极简单灯模式。
- **自动配置 hooks**：首次启动会写入 `~/.claude/settings.json`，托盘菜单也提供重新写入和手动配置复制。
- **主题与声音**：支持深色、浅色外观以及可静音的状态提示音。
- **使用统计**：记录红灯、绿灯次数和红灯持续时间，并可查看本周周报。

## State Model

| 灯色 | 含义 | Claude Code 事件 |
| --- | --- | --- |
| 绿灯 | Claude 已完成回复，可以继续输入下一条指令 | `Stop` |
| 黄灯 | Claude 正在思考、调用工具或输出内容 | `Start` / `UserPromptSubmit` |
| 红灯 | 会话需要用户选择、输入或处理异常 | `PreToolUse` + `AskUserQuestion` |

## Install

### Download

从 [Releases](https://github.com/TaylorSimery/claude-traffic-light/releases) 下载最新版本：

- macOS: 下载 `.dmg`
- Windows: 下载 `.exe`

安装后启动应用即可。首次启动时，应用会自动检测并写入 Claude Code hooks。

### Build From Source

```bash
git clone https://github.com/TaylorSimery/claude-traffic-light.git
cd claude-traffic-light
npm install

# development
npm run dev

# production build
npm run build

# package for macOS
npm run dist

# package for Windows
npm run dist:win
```

## How It Works

应用会在本机维护一个轻量状态文件：

- macOS: `/tmp/cc_traffic_light_state`
- Windows: `%USERPROFILE%\.claude\cc_traffic_light_state`

Claude Code hooks 会在关键事件发生时写入对应颜色。Electron 应用每 300ms 读取状态文件，并同步更新悬浮灯、托盘菜单和统计数据。

自动写入的 hooks 包括：

- `Start` -> `yellow`
- `UserPromptSubmit` -> `yellow`
- `Stop` -> `green`
- `PreToolUse` with `AskUserQuestion` -> `red`

## Requirements

- macOS 10.13+ or Windows 10+
- Node.js 18+ for source builds
- Claude Code installed and able to read `~/.claude/settings.json`

## Troubleshooting

**红绿灯没有变化**

确认 Claude Code 的 settings 文件可写，然后在托盘菜单中选择“重新写入配置”。也可以使用“查看配置路径”确认当前 hooks 写入位置。

**Claude Code 读取的不是这个配置文件**

打开托盘菜单中的“复制手动配置”，把生成的 hooks 片段放到 Claude Code 实际读取的 `settings.json` 内。

**如何卸载 hooks**

删除应用后，打开 Claude Code 的 `settings.json`，移除命令中包含 `cc_traffic_light_state` 的 hooks 条目。

## Tech Stack

- React + TypeScript + Vite
- Electron
- Tailwind CSS / shadcn/ui components
- electron-builder

## License

MIT
