---
title: Capturing
description: Get requirements into Jot from the terminal, scripts and agents.
group: guides
order: 1
---

Capturing is meant to cost less than forgetting. `jot add` asks nothing: the project is inferred, the state is `inbox`, and everything else can be filled in later.

## One requirement

```bash
jot add "Search page is slow"
jot add "Search page is slow" --note "Traced to a DB query inside onChange"
```

The title becomes the list entry. `--note` goes into the **Notes** section of the Markdown body; use it for context, a conclusion from a discussion or acceptance criteria. Titles and notes are stored exactly as typed, in any language.

## Where it is filed

| Situation | Result |
|---|---|
| Inside a Git repository (or a worktree of one) | Filed under that repository's project, registered on first use |
| `--project myapp` | Filed under `myapp`, which must already be registered |
| `--unfiled` | No project, even inside a repository |
| Any other directory | No project |

The capture directory is remembered as `origin_cwd`, so [triage](./projects-and-tags.md#triage) can file it later.

## Tags at capture time

```bash
jot add "Ship the new board" --tag v1.2 --tag ui
jot add "Ship the new board" --tag v1.2,ui
```

## Many at once

```bash
jot add --stdin < ideas.txt
printf '%s\n' "Dark mode contrast" "Export as GPX" | jot add --stdin --tag v1.3
```

One requirement per non-empty line; piping into `jot add` without `--stdin` works too, and so does a multi-line title argument. With `--json`, several titles return an array. Capture stops at the first error, keeping the lines before it.

## From an agent

With the [skill](./ai-agents.md) installed, say "note this down: …" or "add a requirement for …". The agent captures with a short `--note` summarizing the conversation, reports the receipt in one line and returns to what it was doing. It does not start implementing the requirement.

## The body

Every requirement has a Markdown file with three sections:

```markdown
## Requirement

Search page is slow

## Acceptance criteria

- [ ] 

## Notes

Traced to a DB query inside onChange
```

Edit it with `jot edit 42`, replace it with `jot body set 42 < body.md`, or use the editor in the app. See [Files and data](../reference/data-model.md).

## Good habits

- Write the title as the outcome you want ("Search returns in under 200 ms"), not the activity.
- Capture first, organize later; the inbox is supposed to be messy.
- Put the evidence you have right now into `--note`; it is the part you will not remember.
