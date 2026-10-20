---
title: AI agents
description: Set up Claude Code, Codex and other agents to capture and organize requirements for you.
group: guides
order: 5
---

Jot is built to be driven by coding agents as much as by people. An agent needs two things: the `jot` CLI, whose `--json` output is a stable contract, and the skill file, which tells it when and how to call the CLI.

## Setup an agent can follow

1. **Install the CLI** (macOS or Linux):

   ```bash
   os=$(uname -s | tr A-Z a-z); arch=$(uname -m)
   [ "$arch" = x86_64 ] && arch=amd64; [ "$arch" = aarch64 ] && arch=arm64
   curl -fsSL "https://github.com/RedHiwiK/jot/releases/latest/download/jot_${os}_${arch}.tar.gz" | tar -xz -C /tmp
   mkdir -p ~/.local/bin && mv "/tmp/jot_${os}_${arch}/jot" ~/.local/bin/jot
   ```

   With Go instead: `go install github.com/RedHiwiK/jot/cmd/jot@latest`.

2. **Check the binary.** macOS ships an unrelated `/usr/bin/jot`; `~/.local/bin` must come before `/usr/bin` in `PATH`.

   ```bash
   jot --version     # expect: jot version 0.1.0
   ```

3. **Initialize** once: `jot init`.

4. **Install the skill**:

   ```bash
   # Claude Code
   mkdir -p ~/.claude/skills/jot
   curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.claude/skills/jot/SKILL.md

   # Codex
   mkdir -p ~/.codex/skills/jot
   curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.codex/skills/jot/SKILL.md
   ```

   From a clone, symlink instead so updates follow `git pull`: `ln -s "$PWD/skills/jot" ~/.claude/skills/jot`.

5. **Agents without skills** (Cursor and others): paste the contents of [`SKILL.md`](https://github.com/RedHiwiK/jot/blob/main/skills/jot/SKILL.md) into the project rules (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules`).

The whole documentation is also available as a single file for agents: [`llms-full.txt`](https://kunkunred.hiwik.cn/en/projects/jot/llms-full.txt).

## What to say

| You say | The agent runs |
|---|---|
| "Note this down: search is slow" | `jot add "Search is slow" --note "..."` |
| "What's on my plate?" | `jot ls --json`, then a short summary |
| "What's left for myapp?" | `jot ls --project myapp --json` |
| "Clean up the inbox" | `jot ls --state inbox --json`, `jot triage ...`, `jot tag ...` |
| "Tag these for v1.2" | `jot tag 42 43 44 v1.2` |
| "Mark 42 as done" | `jot mv 42 done --json` |
| "What did we ship in v1.2?" | `jot ls --tag v1.2 --all --json` |
| (after opening a PR for 42) | `jot link 42 <pr-url>`, and `JOT-42` in the PR title |

## How the skill behaves

- It captures without interrogating you about project or priority, summarizes the receipt in one line and returns to the original task.
- It does not start implementing a requirement unless you ask.
- It summarizes JSON instead of pasting it.
- It reports batch failures (`failed` and the exit code) instead of calling a partial result a success.
- It never runs `jot purge` unless you explicitly ask to delete something permanently.
- It respects `JOT_HOME` and never edits another tool's configuration.

## Contract for scripts and agents

- Use `--json` for anything that is parsed; see [JSON output](../reference/json-output.md).
- Exit code `0` means success. Batch commands return `{reqs, failed}` and exit non-zero on any failure.
- Errors go to stderr as `error: ...`.
- `JOT_HOME` selects the store, which keeps tests and experiments away from real data.
