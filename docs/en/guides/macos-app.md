---
title: The macOS app
description: Browse and maintain requirements on a native board.
group: guides
order: 4
---

Jot.app is a native SwiftUI board for macOS 14 and later. It is for browsing and maintaining requirements; capturing happens in the CLI or through an agent, so the app has no "new requirement" form.

The app reads and writes only through the CLI bundled at `Jot.app/Contents/Helpers/jot`. The app, the CLI and the skill therefore always see the same store and follow the same rules.

## Layout

- **Sidebar** — all active requirements, each state (Inbox, In Progress, On Hold, Done) with counts, and your projects. A project's folder icon uses its color.
- **Board** — one column per active state. Drag a card to another column to change its state.
- **Detail** — the Markdown body, title, tags and linked pull requests. Double-click the title to rename it; choose **Edit** to change the body, then **Save** or **Cancel**.
- **Inspector** — ID (click to copy), project, capture directory and dates. Toggle it with <kbd>⌥⌘I</kbd>.

Click a tag on a requirement to see the active requirements carrying it.

## Search

<kbd>⌘F</kbd> opens a search over ID, title, project, state and capture note, across active and historical requirements. Use the arrow keys to select, <kbd>Return</kbd> to open and <kbd>Esc</kbd> to close.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| <kbd>⌘1</kbd> … <kbd>⌘5</kbd> | Board, Inbox, In Progress, On Hold, Done |
| <kbd>⌥1</kbd> … <kbd>⌥9</kbd> | Projects in sidebar order (hold <kbd>⌥</kbd> to see the numbers) |
| <kbd>⌘F</kbd> | Search |
| <kbd>⌘R</kbd> | Refresh |
| <kbd>⌥⌘I</kbd> | Toggle the inspector |
| <kbd>⌘[</kbd> | Back |

All shortcuts can be changed in **Settings → Shortcuts**.

## Settings

Open Settings with <kbd>⌘,</kbd> or the gear at the bottom of the sidebar.

| Page | What you can do |
|---|---|
| General | Switch the language between English and Simplified Chinese |
| Appearance | Pick a theme: Newsprint, Paper, Solarized Light, One Dark, or your own |
| Projects | Reorder projects in the sidebar (this also sets <kbd>⌥1</kbd>…<kbd>⌥9</kbd>), rename or remove them, set the repository URL |
| Shortcuts | Record a new binding for any action |
| Archived | Browse archived requirements and move them back to Inbox |

Project colors are set with `jot project set <name> --color <color>`; the app shows them but has no editor for them.

### Custom themes

Choose **Export template** on the Appearance page to write a sample theme to `~/.jot/themes/`. Copy it, change the name and colors, then choose **Rescan**. Every `*.json` file in that folder appears as a theme; colors it leaves out fall back to Paper.

## Staying in sync

Changes made through the CLI or an agent appear within 15 seconds, or immediately with <kbd>⌘R</kbd>. Edits made in the app are written through the CLI before the view updates; if a write fails, the error stays visible and your text is kept.

## Trying it with throwaway data

The app passes its environment to the CLI, so `JOT_HOME` works:

```bash
JOT_HOME=/tmp/jot-demo jot init
JOT_HOME=/tmp/jot-demo /Applications/Jot.app/Contents/MacOS/Jot
```

If the bundled CLI is missing (for example when running from `swift run`), the app looks for `~/.local/bin/jot`, `/usr/local/bin/jot` and `/opt/homebrew/bin/jot`.
