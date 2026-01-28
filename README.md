# Claude Notify

A native macOS SwiftUI notification app for Claude Code and OpenCode. When Claude finishes a response, a frosted-glass floating panel appears with an audible chime. Clicking "Open Project" activates your editor and focuses the correct project window.

**Author:** Andrew Naegele
**Platform:** macOS 14+ (tested on macOS 26 Tahoe)
**Design:** Frosted glass with lava/magma accent gradients

---

## What You Get

- **Audible Glass chime** when Claude stops responding
- **Floating frosted-glass panel** appears above all windows (including full-screen)
- **"Open Project" button** activates your editor and opens the correct project window
- **Auto-dismisses** after 30 seconds if ignored
- **Permission alerts** with distinct Ping sound when Claude needs approval
- Works with both **Claude Code** and **OpenCode**
- **Supports:** Zed, VS Code, Cursor, Windsurf, Void, Sublime Text, Fleet, Nova, Warp

---

## Install with Homebrew (recommended)

```bash
brew tap vibe-marketer/claude-notify
brew install claude-notify
claude-notify-setup
```

The setup command walks you through choosing your editor and configuring Claude Code / OpenCode hooks. You only need to run it once -- future `brew upgrade claude-notify` updates the binary without re-running setup.

---

## Manual Installation

### 1. Install the binary

```bash
mkdir -p ~/.local/bin
cp bin/claude-notify ~/.local/bin/claude-notify
chmod +x ~/.local/bin/claude-notify
```

### 2. Run setup

```bash
./bin/claude-notify-setup
```

This installs the hook script, patches your settings, and lets you pick your editor.

### 3. Restart Claude Code / OpenCode

---

## Files

```
claude-notify/
  README.md                     -- This file
  Package.swift                 -- Swift package manifest
  Sources/
    main.swift                  -- Full SwiftUI source code
  bin/
    claude-notify               -- Pre-built macOS arm64 binary
    claude-notify-setup         -- Interactive setup script
  hooks/
    notify-complete.sh          -- Hook script (launches the binary)
```

---

## Building from Source

If you need to rebuild (e.g., for a different architecture or macOS version):

```bash
swift build -c release
cp .build/release/claude-notify ~/.local/bin/claude-notify
```

---

## Configuration

### Editor

Your editor preference is stored in `~/.config/claude-notify/config`.

**Single editor** -- one "Open Project" button:
```
EDITOR=zed
```

**Multiple editors** -- a button for each in the notification panel:
```
EDITORS=zed,vscode,warp
```

Supported values: `zed`, `vscode`, `cursor`, `windsurf`, `void`, `sublime`, `fleet`, `nova`, `warp`

To change your editors, either edit the file directly or re-run `claude-notify-setup`.

### Sound

Edit `Sources/main.swift` -- find the `afplay` line near the bottom and change the sound file:
- Available: `Basso`, `Blow`, `Bottle`, `Frog`, `Funk`, `Glass`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`

### Auto-dismiss timeout

Edit `Sources/main.swift` -- find `withTimeInterval: 30` and change the value (seconds).

### Panel position

Edit `Sources/main.swift` -- find the screen positioning block and adjust the `x` and `y` calculations.

---

## Uninstall

**Homebrew:**
```bash
brew uninstall claude-notify
rm -rf ~/.config/claude-notify
rm ~/.claude/hooks/notify-complete.sh
rm ~/.config/opencode/hooks/notify-complete.sh
```

**Manual:**
```bash
rm ~/.local/bin/claude-notify
rm ~/.local/bin/claude-notify-setup
rm -rf ~/.config/claude-notify
rm ~/.claude/hooks/notify-complete.sh
rm ~/.config/opencode/hooks/notify-complete.sh
```

Then remove the `Stop` and `Notification` entries from your settings.json files.

---

## How It Works

1. Claude Code / OpenCode fires the **Stop** hook when it finishes a response
2. The hook script reads the working directory from the hook's JSON stdin
3. It launches `claude-notify` with runtime name, project name, and path as arguments
4. The SwiftUI app renders a borderless floating panel at `NSPanel.level.screenSaver` (above everything)
5. `afplay` plays the Glass chime in the background
6. Clicking "Open Project" activates your configured editor and opens the project
7. The app terminates after the action or 30-second timeout

---

(c) 2026 Andrew Naegele | All Rights Reserved
@andrew_naegele -- https://x.com/andrew_naegele
