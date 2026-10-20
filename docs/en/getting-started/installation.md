---
title: Installation
description: Install the macOS app, the CLI and the agent skill.
group: getting-started
order: 2
---

Jot has three parts you can install independently: the macOS app (which includes the CLI), the CLI on its own, and the agent skill.

## Let your agent install it

Paste this into Claude Code, Codex or any coding agent:

```text
Install the jot CLI and its skill by following https://github.com/RedHiwiK/jot/blob/main/docs/en/guides/ai-agents.md
```

## macOS app

Requires macOS 14 or later, Apple silicon or Intel.

```bash
curl -fsSLO https://github.com/RedHiwiK/jot/releases/latest/download/Jot_macos.zip
ditto -x -k Jot_macos.zip /Applications
xattr -dr com.apple.quarantine /Applications/Jot.app
```

The app is ad-hoc signed but not notarized, so Gatekeeper blocks the first launch. The `xattr` command removes the quarantine flag; alternatively, right-click Jot.app and choose **Open** once.

The app bundles a matching CLI. Expose it on your `PATH` to use the same binary in the terminal:

```bash
mkdir -p ~/.local/bin
ln -sf /Applications/Jot.app/Contents/Helpers/jot ~/.local/bin/jot
```

## CLI only

macOS or Linux, arm64 or amd64.

With Go 1.27 or later:

```bash
go install github.com/RedHiwiK/jot/cmd/jot@latest
```

Or from a release archive:

```bash
os=$(uname -s | tr A-Z a-z); arch=$(uname -m)
[ "$arch" = x86_64 ] && arch=amd64; [ "$arch" = aarch64 ] && arch=arm64
curl -fsSL "https://github.com/RedHiwiK/jot/releases/latest/download/jot_${os}_${arch}.tar.gz" | tar -xz -C /tmp
mkdir -p ~/.local/bin && mv "/tmp/jot_${os}_${arch}/jot" ~/.local/bin/jot
```

Each archive also contains `skills/jot/SKILL.md`.

## Check the binary

macOS ships an unrelated `/usr/bin/jot` that prints sequential numbers. Put `~/.local/bin` (or your Go bin directory) before `/usr/bin` in `PATH`, then check:

```bash
jot --version
# jot version 0.1.0
```

If you see numbers instead, see [Troubleshooting](../help/troubleshooting.md#jot-prints-numbers).

## Initialize the store

```bash
jot init
```

This creates `~/.jot`. Set `JOT_HOME` to use another directory; see [Configuration](../reference/configuration.md).

## Agent skill

```bash
# Claude Code
mkdir -p ~/.claude/skills/jot
curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.claude/skills/jot/SKILL.md

# Codex
mkdir -p ~/.codex/skills/jot
curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.codex/skills/jot/SKILL.md
```

More options, including agents without skill support: [AI agents](../guides/ai-agents.md).

## Build from source

Requires Go 1.27+, and Swift 6 with macOS 14+ for the app.

```bash
git clone https://github.com/RedHiwiK/jot.git && cd jot
make install       # CLI to ~/.local/bin/jot
make install-app   # Jot.app to /Applications
```

## Uninstall

```bash
rm -rf /Applications/Jot.app ~/.local/bin/jot ~/.claude/skills/jot ~/.codex/skills/jot
rm -rf ~/.jot      # deletes every requirement; back it up first if unsure
```
