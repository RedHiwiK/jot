---
title: Quick start
description: Capture, organize and finish your first requirements in five minutes.
group: getting-started
order: 3
---

This walkthrough assumes the CLI is installed and `jot --version` prints `jot version ...`. To try it without touching your real store, run `export JOT_HOME=$(mktemp -d)` first.

## 1. Initialize

```bash
jot init
```

## 2. Capture inside a repository

```bash
cd ~/code/myapp
jot add "Search page is slow" --note "Traced to a DB query inside onChange"
# ✓ #1 captured into INBOX  myapp
```

Because you are inside a Git repository, Jot registered it as the project `myapp` and filed the requirement there. Nothing was asked.

## 3. Capture something personal

```bash
jot add "Renew the developer certificate" --unfiled
```

`--unfiled` skips project inference. Outside a repository, requirements are project-less anyway.

## 4. Tag and list

```bash
jot tag 1 v1.2 bug
jot ls
```

```text
INBOX (2)
  #2    Renew the developer certificate    —        just now
  #1    Search page is slow                myapp    just now  bug v1.2
```

## 5. Move it along

```bash
jot mv 1 in_progress
jot mv 1 done
jot ls --all
```

## 6. Read and edit the body

```bash
jot show 1        # metadata and the Markdown body
jot edit 1        # opens the body in your editor
```

Each requirement is a Markdown file under `~/.jot/reqs/`; see [Files and data](../reference/data-model.md).

## 7. Open the app

Launch Jot.app. The board shows Inbox, In Progress and On Hold; drag cards between columns, double-click a title to rename it, and press <kbd>⌘F</kbd> to search. See [The macOS app](../guides/macos-app.md).

## 8. Hand it to your agent

Install the [skill](../guides/ai-agents.md), then just talk: "note this down: the export button is hidden on small windows", "what's on my plate for myapp?", "mark 1 as done".

## Next

- [Capturing](../guides/capturing.md) in depth
- [CLI reference](../reference/cli.md)
