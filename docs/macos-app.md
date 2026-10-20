# macOS app

Jot.app is a native SwiftUI board for browsing and maintaining requirements. It needs macOS 14 or later and works on Apple silicon and Intel Macs.

Capture happens through the CLI or an agent; the app has no "new requirement" form. It reads and writes only through the CLI bundled at `Jot.app/Contents/Helpers/jot`, so the app, the CLI and the skill always see the same store.

## Install

From a release:

```bash
curl -fsSLO https://github.com/RedHiwiK/jot/releases/latest/download/Jot_macos.zip
ditto -x -k Jot_macos.zip /Applications
xattr -dr com.apple.quarantine /Applications/Jot.app   # the app is ad-hoc signed, not notarized
```

Without the `xattr` step, Gatekeeper refuses to open the app; alternatively, right-click Jot.app → Open once.

From source (Go and Swift 6 toolchains):

```bash
make install-app     # builds macos/build/Jot.app and copies it to /Applications
```

The bundled CLI can double as your command-line `jot`:

```bash
mkdir -p ~/.local/bin
ln -sf /Applications/Jot.app/Contents/Helpers/jot ~/.local/bin/jot
```

If no bundled CLI is present (for example when running from `swift run`), the app falls back to `~/.local/bin/jot`, `/usr/local/bin/jot` and `/opt/homebrew/bin/jot`.

## Using it

- **Sidebar:** all active requirements, each state (Inbox, In Progress, On Hold, Done) and projects. Click a tag on a requirement to see the active requirements carrying it. Archived requirements stay out of the board; find them with search or `jot ls --all --state archived`.
- **Board:** one column per active state. Drag cards between columns to change state.
- **Detail:** the Markdown body with an Edit mode (Save / Cancel), inline title editing (double-click), tags, bound PR/MR links, and an inspector with ID, source and dates.
- **Search:** <kbd>⌘F</kbd> searches ID, title, project, state and capture note across active and historical requirements.
- **Settings:** language (English / 简体中文), appearance and keyboard shortcuts.

Default shortcuts, all customizable in Settings:

| Shortcut | Action |
|---|---|
| <kbd>⌘1</kbd> … <kbd>⌘5</kbd> | Board, Inbox, In Progress, On Hold, Done |
| <kbd>⌥1</kbd> … <kbd>⌥9</kbd> | Projects in sidebar order (hold <kbd>⌥</kbd> to see them) |
| <kbd>⌘F</kbd> | Search |
| <kbd>⌘R</kbd> | Refresh |
| <kbd>⌥⌘I</kbd> | Toggle the inspector |
| <kbd>⌘[</kbd> | Back |

Changes made through the CLI or an agent show up within 15 seconds, or immediately with <kbd>⌘R</kbd>.

## Separate stores

The app inherits `JOT_HOME` from its environment, which is handy for trying it with throwaway data:

```bash
JOT_HOME=/tmp/jot-demo jot init
JOT_HOME=/tmp/jot-demo /Applications/Jot.app/Contents/MacOS/Jot
```

## Design rules

- Cards, rows and group headers use status colors only. A project's color tints only its folder icon in the sidebar.
- Low-frequency settings, such as project color or repository URL, are set through the CLI; the app displays them but has no editor for them.
- Colors and spacing come from the theme tokens in `macos/Sources/Jot/Theme`; UI text comes from `macos/Sources/Jot/i18n/Strings.swift`.
