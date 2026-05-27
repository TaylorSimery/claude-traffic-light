#!/bin/bash
set -euo pipefail

TARGET_DIR="$HOME/traffic_light"
TARGET="$TARGET_DIR/hook.sh"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR/hook.sh" "$TARGET"
chmod +x "$TARGET"

echo "Installed Claude Traffic Light hook to $TARGET"
echo "Add this command to Claude Code hooks if it is not already present:"
echo '"$HOME/traffic_light/hook.sh"'
