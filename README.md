# Claude Traffic Light

Claude Traffic Light is a native macOS SwiftUI app that shows the current Claude Code state as a glanceable traffic light.

- Yellow: Claude is thinking, streaming output, or running tools.
- Green: The last turn ended cleanly.
- Red: A permission prompt, tool failure, or session exit needs attention.

The app reads `~/.claude/traffic_light_status` written by a Claude Code hook and falls back to scanning the latest Claude JSONL transcript under `~/.claude/projects`.

## Build

Open `ClaudeTrafficLight.xcodeproj` in Xcode and build the `ClaudeTrafficLight` scheme.

Command-line build:

```sh
xcodebuild -project ClaudeTrafficLight.xcodeproj -scheme ClaudeTrafficLight -configuration Release -derivedDataPath build/DerivedData build
```

## Install Hook

Run:

```sh
ClaudeTrafficLight/Scripts/install-hook.sh
```

Then make sure `~/.claude/settings.json` includes the hook command on these events:

- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `PermissionRequest`
- `Stop`
- `SessionEnd`
- `SessionStart`
- `PreCompact`
- `SubagentStop`

Hook command:

```json
{
  "type": "command",
  "command": "\"$HOME/traffic_light/hook.sh\""
}
```

## Website

The GitHub Pages site lives in `docs/`.
