---
title: Workflow
description: The five states, moving between them, archiving and deleting.
group: guides
order: 3
---

Jot has five states. Each one records what you intend, not whether some process is running.

| State | Meaning | Shown on the board |
|---|---|---|
| `inbox` | Captured, not started | Yes |
| `in_progress` | Being worked on, including review and acceptance | Yes |
| `on_hold` | Deferred, or waiting on something external | Yes |
| `done` | Finished | Sidebar only |
| `archived` | Not going to happen; still searchable and restorable | No |

## Changing state

```bash
jot mv 42 in_progress
jot mv 42 on_hold
jot mv 42 done
jot mv 42 inbox
```

In the app, drag a card to another column. Any state can move to any other; every transition is recorded with its time and actor in the state log.

## Archive and restore

```bash
jot rm 42            # archive
jot mv 42 inbox      # restore
```

Archiving keeps the requirement and its Markdown file. Archived requirements stay out of the board and default listings; find them with `jot ls --all --state archived`, the app's search, or **Settings → Archived**, which can also restore them.

## Permanent deletion

```bash
jot purge 42             # asks for confirmation
jot purge 42 43 --yes
```

`purge` only accepts archived requirements. It removes the database rows, tags, links, state history and the Markdown file. It cannot be undone; prefer archiving.

In the app, right-click a card or row and choose **Delete…**. After you confirm, the app archives the requirement if needed and then purges it.

## A typical week

1. Capture freely during the day; everything lands in **Inbox**.
2. Once or twice a week, open the inbox: [triage](./projects-and-tags.md#triage) projects, tag the release, archive what no longer matters.
3. Move what you start to **In Progress**; park blocked items in **On Hold** with a note in the body saying what they wait for.
4. Mark items **Done** when they ship; `jot ls --tag v1.2 --all` shows the whole release.

## Priority

```bash
jot set 42 --priority 1      # high
jot set 42 --priority 0      # normal
```

High-priority requirements are listed first within each state by `jot ls` and in JSON results. Priority does not affect states, and the app does not display it.
