# Claude Traffic Light

Claude Traffic Light is a native macOS SwiftUI app that shows the current Claude Code state as a glanceable traffic light.

- Yellow: Claude is thinking, streaming output, or running tools.
- Green: The last turn ended cleanly.
- Red: A permission prompt, tool failure, or session exit needs attention.

The app reads the newest Claude JSONL transcript under `~/.claude/projects` and infers the current state directly from the log.

## Build

Open `ClaudeTrafficLight.xcodeproj` in Xcode and build the `ClaudeTrafficLight` scheme.

Command-line build:

```sh
xcodebuild -project ClaudeTrafficLight.xcodeproj -scheme ClaudeTrafficLight -configuration Release -derivedDataPath build/DerivedData build
```

## Website

The GitHub Pages site lives in `docs/`.
