# Using Jot with AI agents

Jot is built to be driven by coding agents (Claude Code, Codex, Cursor and others) as much as by people. The agent gets two things: the `jot` CLI, whose `--json` output is a stable contract, and a skill file that teaches it when and how to call the CLI.

## Setup an agent can follow

1. Install the CLI (macOS or Linux):

   ```bash
   os=$(uname -s | tr A-Z a-z); arch=$(uname -m); [ "$arch" = x86_64 ] && arch=amd64; [ "$arch" = aarch64 ] && arch=arm64
   curl -fsSL "https://github.com/RedHiwiK/jot/releases/latest/download/jot_${os}_${arch}.tar.gz" | tar -xz -C /tmp
   mkdir -p ~/.local/bin && mv "/tmp/jot_${os}_${arch}/jot" ~/.local/bin/jot
   ```

   Or with Go: `go install github.com/RedHiwiK/jot/cmd/jot@latest` (installs to `$(go env GOPATH)/bin`).

2. Make sure the right binary is found. macOS ships an unrelated `/usr/bin/jot`; `~/.local/bin` must come before `/usr/bin` in `PATH`. Check with:

   ```bash
   jot --version     # expect: jot version 0.1.0 (BSD jot prints numbers instead)
   ```

3. Initialize the store once: `jot init` (creates `~/.jot`).

4. Install the skill:

   ```bash
   # Claude Code
   mkdir -p ~/.claude/skills/jot
   curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.claude/skills/jot/SKILL.md

   # Codex
   mkdir -p ~/.codex/skills/jot
   curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.codex/skills/jot/SKILL.md
   ```

   From a clone, symlink instead so updates follow `git pull`: `ln -s "$PWD/skills/jot" ~/.claude/skills/jot`. For agents without skill support, paste [`skills/jot/SKILL.md`](../skills/jot/SKILL.md) into the project instructions (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules`).

## What the agent does with it

Typical requests and the calls behind them:

| You say | Agent runs |
|---|---|
| "Note this down: search is slow" | `jot add "Search is slow" --note "..."` |
| "What's on my plate?" | `jot ls --json`, then a short summary |
| "Clean up the inbox" | `jot ls --state inbox --json`, `jot triage ... --json`, `jot tag ...` |
| "Mark 42 as done" | `jot mv 42 done --json` |
| "Everything for v0.2" | `jot ls --tag v0.2 --all --json` |
| After opening a PR for a requirement | `jot link 42 <pr-url>` and `JOT-42` in the PR title |

The skill tells the agent to capture without interrogating you, to return to its original task afterwards instead of implementing the requirement, never to `purge` during routine tidying, and to report batch failures instead of calling them success.

## Contract for scripts and agents

- Use `--json` for anything parsed. Requirement objects carry `id, title, priority, state, project, tags, links, path, note, origin_cwd, created_at, updated_at`; empty fields are omitted.
- Exit code 0 means success. Batch commands return `{reqs, failed}` and exit non-zero on any failure.
- `JOT_HOME` selects the store, which keeps tests and experiments away from real data.
- Read [cli.md](cli.md) for every command and [data-model.md](data-model.md) for the files on disk.
