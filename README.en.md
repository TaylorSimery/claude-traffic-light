# Claude Traffic Light

Tiny native macOS traffic-light widget for Claude Code.

[Website](https://taylorsimery.github.io/claude-traffic-light/) ·
[Download Releases](https://github.com/TaylorSimery/claude-traffic-light/releases) ·
[中文 README](README.md)

<p align="center">
  <a href="https://taylorsimery.github.io/claude-traffic-light/">
    <img src="docs/traffic-light-icon.png" width="180" alt="Claude Traffic Light icon">
  </a>
</p>

<p align="center">
  <img src="docs/UI.png" width="180" alt="Claude Traffic Light UI">
</p>

## Why

Claude Code runs in a terminal. Once you switch to another window, you cannot tell whether Claude is still working, already done, or stuck waiting for your approval.

Claude Traffic Light turns that state into a tiny desktop signal:

- Yellow: Claude is thinking, streaming, or using tools.
- Green: the last turn completed cleanly.
- Red: Claude Code is closed, interrupted, waiting for permission, or in an error state.

## Features

- Native SwiftUI.
- No Electron.
- No Python.
- No helper scripts inside the app.
- No Dock icon.
- No menu bar icon.
- Runs as an `LSUIElement` background widget.
- Floats above all windows and Spaces, including full-screen apps.
- Drag from anywhere.
- Right-click to quit.
- Reads local Claude Code transcripts under `~/.claude/projects/**/*.jsonl`.

## Install

1. Open [Releases](https://github.com/TaylorSimery/claude-traffic-light/releases).
2. Download `ClaudeTrafficLight.zip`.
3. Unzip it.
4. Move `ClaudeTrafficLight.app` into `/Applications`.
5. Right-click the app and choose **Open** for the first launch.
6. Start Claude Code with `claude`.

If macOS blocks the app:

```sh
xattr -dr com.apple.quarantine /Applications/ClaudeTrafficLight.app
```

## Troubleshooting

If the widget stays red:

1. Make sure Claude Code is running in Terminal.
2. Submit at least one prompt.
3. Check that new `.jsonl` files appear under `~/.claude/projects`.
4. Relaunch Claude Traffic Light.

The widget has no Dock or menu bar icon by design. Right-click the widget to quit.

## Build

```sh
git clone https://github.com/TaylorSimery/claude-traffic-light.git
cd claude-traffic-light
xcodebuild -project ClaudeTrafficLight.xcodeproj -scheme ClaudeTrafficLight -configuration Release -derivedDataPath build/DerivedData build
```
