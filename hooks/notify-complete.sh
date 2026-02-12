#!/bin/bash
# Claude/OpenCode Notification Hook
# Usage: bash notify-complete.sh [permission]
# Launches the claude-notify SwiftUI app for Stop and Notification hooks
#
# Arguments passed to claude-notify:
#   $1 = runtime (Claude | OpenCode)
#   $2 = project name
#   $3 = project path
#   $4 = editor (Zed | Cursor | VSCode | Windsurf | Terminal | Unknown)
#   $5 = tty device (e.g. /dev/ttys024) for terminal window focusing
#   $6 = mode (permission | "")

MODE="${1:-}"  # "permission" or empty for completion

# Read hook input from stdin to get the working directory and session info
INPUT=$(cat)
HOOK_CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)

CWD="${HOOK_CWD:-$(pwd)}"
PROJECT_NAME=$(basename "$CWD")

# Detect which runtime triggered this
RUNTIME="Claude"
if echo "$0" | grep -qi "opencode"; then
    RUNTIME="OpenCode"
fi

# ── Detect the TTY of the parent process ──────────────────────────────
# The hook runs with stdin piped (JSON), so `tty` won't work.
# But the parent process (claude/opencode) has the real tty.
TTY_DEVICE=""
PARENT_TTY=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
if [ -n "$PARENT_TTY" ] && [ "$PARENT_TTY" != "??" ]; then
    TTY_DEVICE="/dev/$PARENT_TTY"
fi

# ── Detect the IDE/editor ──────────────────────────────────────────────
# Strategy:
#   1. Check Claude Code's IDE lock files (~/.claude/ide/*.lock)
#      These contain JSON like: {"pid":58443,"ideName":"Cursor",...}
#      We match against the CWD to find the right one.
#   2. Check parent process tree for known editors
#   3. Check TERM_PROGRAM env var (for terminal sessions)
#   4. Fallback to "Terminal"

EDITOR_NAME=""

# 1. Check IDE lock files (Claude Code creates these when running in an editor)
if [ -d "$HOME/.claude/ide" ]; then
    for lockfile in "$HOME/.claude/ide"/*.lock; do
        [ -f "$lockfile" ] || continue
        IDE_NAME=$(python3 -c "
import sys, json
try:
    data = json.load(open('$lockfile'))
    folders = data.get('workspaceFolders', [])
    ide = data.get('ideName', '')
    cwd = '$CWD'
    # Check if our CWD is within any of the workspace folders
    for f in folders:
        if cwd.startswith(f) or f.startswith(cwd):
            print(ide)
            sys.exit(0)
except:
    pass
" 2>/dev/null)
        if [ -n "$IDE_NAME" ]; then
            EDITOR_NAME="$IDE_NAME"
            break
        fi
    done
fi

# 2. Check parent process tree for known editors
if [ -z "$EDITOR_NAME" ]; then
    CURRENT_PID=$$
    for _ in 1 2 3 4 5 6 7 8; do
        PARENT_PID=$(ps -o ppid= -p "$CURRENT_PID" 2>/dev/null | tr -d ' ')
        [ -z "$PARENT_PID" ] || [ "$PARENT_PID" = "1" ] || [ "$PARENT_PID" = "0" ] && break
        PARENT_NAME=$(ps -o comm= -p "$PARENT_PID" 2>/dev/null)
        case "$PARENT_NAME" in
            *[Zz]ed*)               EDITOR_NAME="Zed"; break ;;
            *[Cc]ursor*)            EDITOR_NAME="Cursor"; break ;;
            *[Cc]ode*|*VSCode*)     EDITOR_NAME="VSCode"; break ;;
            *[Ww]indsurf*)          EDITOR_NAME="Windsurf"; break ;;
            *Terminal*)             EDITOR_NAME="Terminal"; break ;;
        esac
        CURRENT_PID="$PARENT_PID"
    done
fi

# 3. Check TERM_PROGRAM for terminal apps (plain CLI sessions)
if [ -z "$EDITOR_NAME" ]; then
    case "${TERM_PROGRAM:-}" in
        iTerm*|iTerm.app)     EDITOR_NAME="iTerm" ;;
        Apple_Terminal)       EDITOR_NAME="Terminal" ;;
        WezTerm)              EDITOR_NAME="WezTerm" ;;
        Alacritty)            EDITOR_NAME="Alacritty" ;;
        ghostty)              EDITOR_NAME="Ghostty" ;;
        tmux)                 EDITOR_NAME="Terminal" ;;
        vscode)               EDITOR_NAME="VSCode" ;;
    esac
fi

# 4. Fallback
if [ -z "$EDITOR_NAME" ]; then
    EDITOR_NAME="Terminal"
fi

# Find the binary (Homebrew, ~/.local/bin, or PATH)
NOTIFY_BIN=""
if command -v claude-notify >/dev/null 2>&1; then
    NOTIFY_BIN="claude-notify"
elif [ -x "$HOME/.local/bin/claude-notify" ]; then
    NOTIFY_BIN="$HOME/.local/bin/claude-notify"
fi

# Launch the SwiftUI notification app (non-blocking)
# Args: runtime projectName projectPath editor ttyDevice [mode]
if [ -n "$NOTIFY_BIN" ]; then
    "$NOTIFY_BIN" "$RUNTIME" "$PROJECT_NAME" "$CWD" "$EDITOR_NAME" "${TTY_DEVICE:-none}" $MODE &
fi
