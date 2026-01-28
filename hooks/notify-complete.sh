#!/bin/bash
# Claude/OpenCode Notification Hook
# Usage: bash notify-complete.sh [permission]
# Launches the claude-notify SwiftUI app for Stop and Notification hooks

MODE="${1:-}"  # "permission" or empty for completion

# Read hook input from stdin to get the working directory
INPUT=$(cat)
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

CWD="${HOOK_CWD:-$(pwd)}"
PROJECT_NAME=$(basename "$CWD")

# Detect which runtime triggered this
RUNTIME="Claude"
if echo "$0" | grep -qi "opencode"; then
    RUNTIME="OpenCode"
fi

# Find the binary (Homebrew, ~/.local/bin, or PATH)
NOTIFY_BIN=""
if command -v claude-notify >/dev/null 2>&1; then
    NOTIFY_BIN="claude-notify"
elif [ -x "$HOME/.local/bin/claude-notify" ]; then
    NOTIFY_BIN="$HOME/.local/bin/claude-notify"
fi

# Launch the SwiftUI notification app (non-blocking)
if [ -n "$NOTIFY_BIN" ]; then
    "$NOTIFY_BIN" "$RUNTIME" "$PROJECT_NAME" "$CWD" $MODE &
fi
