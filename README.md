# Claude Code 红绿灯 (Traffic Light)

一个优雅的 macOS/Windows 菜单栏应用，实时显示 Claude Code 的工作状态。

## 功能特性

### 🚦 智能状态指示

- **🟢 绿灯**：Claude 已完成回复，可以继续对话
- **🟡 黄灯**：Claude 正在思考、输出或处理中
- **🔴 红灯**：会话中断（需要用户输入、网络问题或异常终止）

### ✨ 其他特性

- **双模式显示**：三灯模式（经典红绿灯）或单灯模式（极简风格）
- **深色/浅色主题**：自动适配系统外观
- **声音提示**：状态切换时播放轻柔提示音（可静音）
- **使用统计**：记录每日红灯/绿灯次数和红灯总时长
- **系统托盘集成**：常驻菜单栏，一键切换设置

## 安装

### 方式一：下载预编译版本

1. 前往 [Releases](https://github.com/TaylorSimery/claude-traffic-light/releases) 页面
2. 下载最新的 `.dmg`（macOS）或 `.exe`（Windows）
3. 安装并启动应用

### 方式二：从源码构建

```bash
# 克隆仓库
git clone https://github.com/TaylorSimery/claude-traffic-light.git
cd claude-traffic-light

# 安装依赖
npm install

# 开发模式运行
npm run dev

# 构建生产版本
npm run build

# 打包 DMG（macOS）
npm run dist

# 打包 NSIS（Windows）
npm run dist:win
```

## 工作原理

应用通过 Claude Code 的 hooks 系统监听以下事件：

- **Start**：Claude 开始输出 → 黄灯
- **Stop**：Claude 完成回复 → 绿灯
- **AskUserQuestion**：需要用户选择选项 → 红灯
- **UserPromptSubmit**：用户提交消息后立即切换到黄灯

首次启动时，应用会自动在 `~/.claude/settings.json` 中配置必要的 hooks。

## 使用说明

1. **启动应用**：双击图标或从应用程序文件夹启动
2. **查看状态**：菜单栏会显示当前状态灯
3. **调整设置**：
   - 点击窗口右上角齿轮图标
   - 切换单灯/三灯模式
   - 切换深色/浅色主题
   - 开启/关闭声音提示
4. **查看统计**：点击窗口底部"统计"按钮查看今日使用数据

## 技术栈

- **前端**：React + TypeScript + Vite
- **UI**：Tailwind CSS + shadcn/ui
- **桌面框架**：Electron
- **构建工具**：electron-builder

## 系统要求

- **macOS**：10.13 或更高版本
- **Windows**：Windows 10 或更高版本
- **Claude Code**：需要安装 Claude Code CLI 或桌面版

## 常见问题

**Q: 红绿灯不工作？**  
A: 确保 Claude Code 已安装且 `~/.claude/settings.json` 文件可写。重启应用会自动配置 hooks。

**Q: 如何卸载？**  
A: 删除应用后，手动编辑 `~/.claude/settings.json`，移除包含 `cc_traffic_light_state` 的 hooks 配置。

**Q: 支持 Linux 吗？**  
A: 目前仅支持 macOS 和 Windows，Linux 支持计划中。

## 开源协议

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- UI 设计灵感来自 macOS 系统风格
- 图标和动画效果基于 Figma 原型
