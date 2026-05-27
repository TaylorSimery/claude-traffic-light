# Claude Traffic Light

Claude Traffic Light is a tiny macOS widget for Claude Code.

它像一枚挂在桌面上的信号灯，帮你一眼判断 Claude Code 现在在做什么。

## What it means

- Yellow / 黄灯: Claude is thinking, streaming, or using a tool.
- Green / 绿灯: the last turn finished cleanly.
- Red / 红灯: Claude Code is not running, is waiting for permission, or has hit an error.

## What you get

- Pure SwiftUI app.
- No Electron.
- No Python.
- No helper scripts inside the app.
- No Dock icon.
- No menu bar icon.
- A borderless widget that floats above normal windows and full-screen spaces.
- Drag from anywhere.
- Right-click to quit.

## Install

### 1. Download the release

Get `ClaudeTrafficLight.zip` from GitHub Releases and unzip it.

### 2. Move the app

Drag `ClaudeTrafficLight.app` into `/Applications`.

### 3. Open it once

Because macOS protects downloaded apps, the first launch may need:

- right-click the app and choose **Open**
- or remove quarantine from Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/ClaudeTrafficLight.app
```

### 4. Launch Claude Traffic Light

You will see the mini traffic light floating near the top-right of your screen.

If Claude Code is not running, the light is red.

## How to use it

- Start Claude Code in Terminal.
- Keep working in other windows.
- Look at the widget when you want a status check.
- Yellow means it is still active.
- Green means the last turn ended cleanly.
- Red means something needs attention, or Claude Code is not running.

## If the light stays red

1. Make sure Claude Code is actually running in Terminal.
2. Run at least one prompt in that session.
3. Check that Claude Code is writing transcripts under `~/.claude/projects`.
4. Reopen the app after Claude Code starts if needed.

## Build from source

Requirements:

- macOS 13 or later
- Xcode 26+

Open the project:

```sh
open ClaudeTrafficLight.xcodeproj
```

Build a Release app:

```sh
xcodebuild -project ClaudeTrafficLight.xcodeproj -scheme ClaudeTrafficLight -configuration Release -derivedDataPath build/DerivedData build
```

The app bundle will be created at:

```sh
build/DerivedData/Build/Products/Release/ClaudeTrafficLight.app
```

## Project layout

```text
ClaudeTrafficLight/
  ClaudeTrafficLightApp.swift
  AppDelegate.swift
  StatusMonitor.swift
  TrafficLightView.swift
  Assets.xcassets/
  Info.plist
docs/
  index.html
```

## FAQ

### Why does it have no Dock icon?

It is an `LSUIElement` background app, so it behaves like a widget rather than a normal windowed app.

### How do I quit?

Right-click the widget and choose the quit item in the menu.

### Can I move it?

Yes. Drag from any empty part of the widget.

### Does it need hooks or scripts?

No. The current version reads Claude Code transcripts directly.

### What if I never see green?

That usually means Claude Code has not finished a turn yet, or the transcript is still changing.

## Website

The project site lives in `docs/` and is published through GitHub Pages.
