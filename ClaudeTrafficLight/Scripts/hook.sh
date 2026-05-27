#!/bin/bash

STATUS_FILE="${CLAUDE_TRAFFIC_LIGHT_STATUS_FILE:-$HOME/.claude/traffic_light_status}"
EVENT_FILE="${CLAUDE_TRAFFIC_LIGHT_EVENT_FILE:-$HOME/.claude/traffic_light_event.json}"

INPUT="$(cat)"

EVENT_NAME="$(printf '%s' "$INPUT" | /usr/bin/python3 -c 'import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    data={}
print(data.get("hook_event_name") or data.get("hookEventName") or "")
')"

STATUS=""
case "$EVENT_NAME" in
    "UserPromptSubmit"|"PreToolUse"|"PostToolUse"|"PreCompact"|"SessionStart"|"SubagentStop")
        STATUS="running"
        ;;
    "Stop")
        STATUS="success"
        ;;
    "PermissionRequest")
        STATUS="error"
        ;;
    "SessionEnd")
        STATUS="error"
        ;;
esac

if [ -n "$STATUS" ]; then
    mkdir -p "$(dirname "$STATUS_FILE")"
    printf '%s\n' "$STATUS" > "$STATUS_FILE"
fi

printf '%s' "$INPUT" | STATUS="$STATUS" EVENT_NAME="$EVENT_NAME" /usr/bin/python3 -c 'import json,os,sys,time
try:
    data=json.load(sys.stdin)
except Exception:
    data={}
event={
    "event": os.environ.get("EVENT_NAME", ""),
    "status": os.environ.get("STATUS", ""),
    "timestamp": time.time(),
    "transcript_path": data.get("transcript_path", ""),
    "cwd": data.get("cwd", ""),
    "tool_name": data.get("tool_name", "")
}
path=os.path.expanduser(os.environ.get("CLAUDE_TRAFFIC_LIGHT_EVENT_FILE", "~/.claude/traffic_light_event.json"))
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(event, f, ensure_ascii=False)
'

exit 0
