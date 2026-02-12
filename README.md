# Claude Notify

Native macOS notifications for Claude Code and OpenCode. A lightweight SwiftUI panel appears when Claude finishes a response or needs permission -- with one click to jump to the exact editor window.

**Author:** Andrew Naegele
**Platform:** macOS 14+ (Sonoma and later)

---

## Features

- **Completion alerts** with Glass chime when Claude stops responding
- **Permission alerts** with distinct Tink sound when Claude needs approval
- **Smart editor detection** -- automatically detects Zed, Cursor, VS Code, Windsurf, Terminal, and more
- **One-click focus** -- brings the exact window/tab to the front, even with multiple editor instances
- **Stacking** -- multiple notifications stack vertically, never overlap
- **Auto-dismiss** with visual countdown bar (30 seconds)
- **Terminal window targeting** -- uses tty matching to focus the exact Terminal.app or iTerm2 tab
- Works with both **Claude Code** and **OpenCode**

### Supported Editors

Zed, Cursor, VS Code, Windsurf, Void, Sublime Text, Fleet, Nova, Warp, iTerm2, WezTerm, Alacritty, Ghostty, Terminal.app

---

## Install

### Homebrew (recommended)

```bash
brew tap vibe-marketer/claude-notify
brew install claude-notify
claude-notify-setup
```

### Manual

```bash
# Build from source
swift build -c release

# Install binary
mkdir -p ~/.local/bin
cp .build/release/claude-notify ~/.local/bin/
chmod +x ~/.local/bin/claude-notify

# Run setup
./bin/claude-notify-setup
```

The setup script installs hook scripts and patches your Claude Code / OpenCode settings. Run it once -- future updates to the binary don't require re-running setup.

---

## How It Works

1. Claude Code / OpenCode fires the **Stop** hook when it finishes a response
2. The hook script detects the runtime (Claude vs OpenCode) and editor (Zed, Cursor, Terminal, etc.)
3. It grabs the tty device from the parent process for terminal window targeting
4. The SwiftUI binary renders a floating panel at `NSPanel.level.screenSaver` (above everything)
5. `afplay` plays an audible chime in the background
6. Clicking the action button activates the correct editor and focuses the right window
7. The panel auto-dismisses after 30 seconds with a visual countdown

### Editor Detection

The hook script uses three strategies in order:

1. **IDE lock files** (`~/.claude/ide/*.lock`) -- Claude Code creates these with `ideName` and `workspaceFolders`. Matched by comparing the session's working directory.
2. **Process tree walk** -- walks up the parent process chain looking for known editor process names (Zed, Cursor, etc.)
3. **`TERM_PROGRAM` env var** -- identifies the terminal emulator for standalone CLI sessions

### Window Focusing

- **Code editors** (Zed, Cursor, VS Code, etc.): Activated via AppleScript, then the editor's CLI command opens/focuses the project path
- **Terminal.app**: AppleScript iterates all windows/tabs, matches by tty device, brings the exact tab to front
- **iTerm2**: Same approach using iTerm2's AppleScript dictionary (windows > tabs > sessions)

---

## Files

```
claude-notify/
  Package.swift              Swift package manifest
  Sources/
    main.swift               SwiftUI notification app
  bin/
    claude-notify-setup      Interactive setup script
  hooks/
    notify-complete.sh       Hook script (detects editor, launches binary)
```

---

## Configuration

### Sounds

Edit `Sources/main.swift` and change the `afplay` sound files:
- Completion: `Glass.aiff` (default)
- Permission: `Tink.aiff` (default)
- Available: `Basso`, `Blow`, `Bottle`, `Frog`, `Funk`, `Glass`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`

### Auto-dismiss timeout

Edit `Sources/main.swift` -- find `withTimeInterval: 30` and change the value (seconds).

---

## Uninstall

**Homebrew:**
```bash
brew uninstall claude-notify
brew untap vibe-marketer/claude-notify
rm ~/.claude/hooks/notify-complete.sh
rm ~/.config/opencode/hooks/notify-complete.sh
```

Then remove the `Stop` and `Notification` entries from:
- `~/.claude/settings.json`
- `~/.config/opencode/settings.json`

---

(c) 2026 Andrew Naegele | All Rights Reserved
[@andrew_naegele](https://x.com/andrew_naegele)
