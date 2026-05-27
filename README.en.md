# Claude Traffic Light

Claude Traffic Light is a tiny macOS widget for Claude Code.

It sits on the desktop like a signal lamp and tells you, at a glance, whether Claude is thinking, done, or needs attention.

## Status colors

- Yellow: Claude is thinking, streaming, or using a tool.
- Green: the last turn ended cleanly.
- Red: Claude Code is not running, is waiting for permission, or has hit an error.

## Features

- Pure SwiftUI app.
- No Electron.
- No Python.
- No helper scripts inside the app.
- No Dock icon.
- No menu bar icon.
- Borderless widget window.
- Floats above normal windows and full-screen spaces.
- Drag from anywhere.
- Right-click to quit.

## Install

### 1. Download the release

Download `ClaudeTrafficLight.zip` from GitHub Releases and unzip it.

### 2. Move the app

Drag `ClaudeTrafficLight.app` into `/Applications`.

### 3. Open it once

The first launch may need:

- right-click the app and choose **Open**
- or remove quarantine from Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/ClaudeTrafficLight.app
```

### 4. Launch the widget

The mini traffic light appears near the top-right of the screen.

If Claude Code is not running, the light is red.

## Usage

- Start Claude Code in Terminal.
- Keep working elsewhere.
- Glance at the widget when you want a status check.
- Yellow means Claude is still active.
- Green means the last turn completed cleanly.
- Red means something needs attention, or Claude Code is not running.

## If the widget stays red

1. Make sure Claude Code is running in Terminal.
2. Run at least one prompt in that session.
3. Confirm Claude Code is writing transcripts under `~/.claude/projects`.
4. Relaunch the app after Claude Code starts if needed.

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

The app bundle is written to:

```sh
build/DerivedData/Build/Products/Release/ClaudeTrafficLight.app
```

## FAQ

### Why no Dock icon?

The app is an `LSUIElement` background app, so it behaves like a widget instead of a normal windowed app.

### How do I quit?

Right-click the widget and choose the quit item in the menu.

### Can I move it?

Yes. Drag from any empty part of the widget.

### Does it need hooks or scripts?

No. The current version reads Claude Code transcripts directly.

### Why is it red when Claude Code is closed?

That is intentional. When Claude Code is not running, the widget should show red.

## Website

The project site lives in `docs/` and is published with GitHub Pages.
