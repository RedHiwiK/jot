---
name: jot
description: Capture, review, and organize personal requirements with the jot CLI; maintain board progress and project categories (add, rename, remove). Use for requests like "note this down", "what's on my plate", "clean up the inbox", or "mark that requirement done".
---

# Personal requirements board

Translate the user's requirement-management intent into `jot` calls and report back briefly. After capturing, return to the original task — do not start implementing on your own.

## Capture

```bash
jot add "Title" --note "Context, conclusion, or acceptance criteria"
jot add "Personal task" --unfiled
jot add "Title" --project registered-project-name
jot add "Title" --tag v1.2.0
jot add --stdin < requirements.txt
```

The project is inferred from the current directory: inside a Git repository it is registered automatically, and in an ordinary directory it may stay empty. Respect an explicit project when the user names one; use `--unfiled` when they ask for a personal task with no project. Do not interrogate the user about project or priority just to capture something.

When the conversation already holds a useful conclusion, save a short summary with `--note` rather than copying whole passages. The default output is a one-line receipt — summarize it directly.

## Review and edit

```bash
jot ls --json
jot ls --all --json
jot ls --project project-name --json
jot ls --state inbox --json
jot ls --tag v1.2.0 --json
jot show 42 --json
jot body 42
jot body set 42 < body.md
jot set 42 --title "New title"
jot set 42 --project project-name
jot set 42 --project ""
jot set 42 --priority 1
```

Prefer JSON for queries, then summarize the user's open items and progress — never paste raw JSON. In `show`, `note` is the full body; in `ls`, `note` is the capture summary. `body set` reads Markdown without frontmatter; the CLI maintains the metadata. `path 42` returns the body file's path.

## Tags

```bash
jot tag 42 v1.2.0                 # add, keeping existing tags
jot tag 42 43 44 v1.2.0           # tag a batch for one release
jot tag 42 --tag 2026             # --tag takes the value literally
jot untag 42 v1.2.0
jot tag 42 --clear
jot set 42 --tags v1.2.0,bug      # replace every tag
jot ls --tag v1.2.0 --tag bug --json   # all of them (AND)
jot ls --tag-any v1.2.0,v1.3.0 --json  # any of them (OR)
jot ls --untagged --json
jot tag ls --json                 # every tag in use, with counts
jot tag rename v1.2.0 v1.3.0
jot tag rm v1.2.0
```

Tags are a free-form dimension orthogonal to project — typically a version number (`v1.2.0`) or a theme (`bug`). They are normalized to lower case and a leading `#` is dropped, so `#V1.2.0` and `v1.2.0` are one tag; letters, digits and `. _ / -` are allowed, and spaces and commas separate tags rather than belonging to one.

In `tag` and `untag`, a leading all-digit argument is read as a requirement ID, so pass an all-digit tag with `--tag` (which takes its value literally and cannot be mixed with positional tags). `tag` and `untag` are incremental and take several IDs; `set --tags` replaces a requirement's tags outright, so reach for it only when the user means to overwrite. There is no tag registry: a tag exists exactly as long as some requirement carries it, which is why `tag ls` is a live view rather than a list to maintain. `tag rm` only drops the label — no requirement is deleted and no state changes. `ls --json` already returns the full tag list alongside the results, so do not call `tag ls` just to discover what exists.

Batch tag operations report per-item results: check `failed` and the exit code, exactly as with other batch commands.

## Organize and change state

```bash
jot triage 42 43 --json
jot triage 42 --project project-name --json
jot mv 42 inbox
jot mv 42 in_progress --json
jot mv 42 on_hold --json
jot mv 42 done --json
jot rm 42
jot mv 42 inbox --json
```

State meanings:

- `inbox`: not started.
- `in_progress`: being worked on; set manually by the user or an authorized agent.
- `on_hold`: deferred, or waiting on an external condition.
- `done`: finished.
- `archived`: no longer pursued, still recoverable.

"Mark it done" maps to `done`; checking and accepting work belong to `in_progress`; deferring maps to `on_hold`. State records requirement progress only — it does not represent process status.

`triage` keeps an existing project: it tries the capture directory first, then the current directory. When no project can be inferred, the current state is kept. Only an explicit `--project` overrides an existing project. For batch operations, check `failed` and the exit code and report partial failures — do not treat a partially failed batch as a success.

`rm` is a recoverable archive. `purge` deletes permanently; use it only when the user explicitly asks to destroy an archived requirement, never as part of routine tidying.

## Projects and setup

```bash
jot init
jot project add project-name /path/to/folder
jot project ls --json
jot project rename old-name new-name
jot project rm project-name --json
jot project set project-name --color blue       # sidebar icon color: red/orange/yellow/green/teal/blue/purple/gray; "" clears
jot project set project-name --repo-url https://github.com/owner/repo   # "" falls back to the git remote
```

`project ls --json` reports `repo_url` — configured, or inferred from the origin remote when `repo_url_inferred` is true. Set `--repo-url` only when the user gives an address or the inferred one is wrong.

## Pull and merge requests

```bash
jot link 42 https://github.com/owner/repo/pull/12
jot unlink 42 https://github.com/owner/repo/pull/12
jot unlink 42 --all
```

After opening a PR or MR that implements a requirement, bind it with `jot link <id> <url>` right away — the GUI shows bound links on the detail page, and nothing else connects the two. `link` is incremental, so binding a second PR keeps the first. In PR/MR titles, descriptions, and commits, refer to the requirement as `JOT-42`, never a bare `#42`, which GitHub and GitLab link to their own issue or PR 42.

When `jot` is not installed (or `jot --version` does not print `jot version ...`, which means macOS's unrelated `/usr/bin/jot` was found first), say so and offer to install it following https://github.com/RedHiwiK/jot/blob/main/docs/en/guides/ai-agents.md. When it is installed but not initialized, a capture task may run `jot init` first. Respect the data location given by `JOT_HOME`, and do not rewrite another tool's configuration.

Report errors when a command fails; never describe a read failure as "no requirements". The GUI, the CLI, and this skill share one local store.

Removing a project only drops the category: every associated requirement — open, done, and archived alike — becomes project-less, keeping its state and body. No repository or requirement file is deleted. Confirm the name with `project ls --json` first, run `project rm name --json`, then query again to confirm. A file-sync failure rolls back and reports an error — do not claim the removal succeeded. Capturing again inside the original repository may re-register the project; use `add --unfiled` when it should stay project-less.
