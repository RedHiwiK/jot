---
title: JSON output
description: The machine-readable shapes returned by --json.
group: reference
order: 2
---

Every data command accepts `--json`. The shapes below are a contract with the macOS app and with agents: fields are added over time, but not renamed or removed. Fields that are empty are omitted, so treat every optional field as possibly missing.

## Requirement

Returned by `add`, `show`, `set`, `mv`, `tag`/`untag` (inside `reqs`) and `ls` (inside `reqs`).

```json
{
  "id": 1,
  "title": "Search page is slow",
  "priority": 0,
  "state": "inbox",
  "project": "myapp",
  "tags": ["v1.2"],
  "links": ["https://github.com/owner/myapp/pull/12"],
  "path": "myapp/0001-2026-10-20-Search-page-is-slow.md",
  "note": "Traced to a DB query inside onChange",
  "origin_cwd": "/home/me/code/myapp",
  "created_at": "2026-10-20T16:55:34+08:00",
  "updated_at": "2026-10-20T16:55:34+08:00"
}
```

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Stable, never reused |
| `title` | string | |
| `priority` | integer | `0` normal, `1` high |
| `state` | string | `inbox`, `in_progress`, `on_hold`, `done`, `archived` |
| `project` | string | Omitted when project-less |
| `tags` | string[] | Normalized, sorted; omitted when empty |
| `links` | string[] | In binding order; omitted when empty |
| `path` | string | Body file relative to `~/.jot/reqs/`; `jot path <id>` prints the absolute path |
| `note` | string | In `ls`: the capture note. In `show`: the whole body without frontmatter |
| `origin_cwd` | string | Directory the requirement was captured in |
| `created_at`, `updated_at` | string | RFC 3339 with offset |

## `ls`

```json
{
  "reqs": [ /* requirement objects */ ],
  "projects": [ /* project objects */ ],
  "tags": [ { "tag": "v1.2", "count": 1 } ],
  "detected_project": "myapp",
  "cwd": "/home/me/code/myapp"
}
```

`projects` and `tags` always describe the whole store, not just the filtered results, so one call is enough to know what exists. `detected_project` is the project the current directory maps to, when there is one.

## Project

Returned by `project ls` (an array) and inside `ls`.

```json
{
  "name": "myapp",
  "repo_path": "/home/me/code/myapp",
  "open_count": 1,
  "color": "blue",
  "repo_url": "https://github.com/owner/myapp",
  "repo_url_inferred": true
}
```

`open_count` counts requirements that are not done or archived. `repo_url_inferred` is `true` when the URL comes from the `origin` remote rather than `project set --repo-url`.

## `tag ls`

```json
{ "tags": [ { "tag": "bug", "count": 2 }, { "tag": "v1.2", "count": 4 } ] }
```

## Batch results

`triage`, `tag` and `untag` process every item and return:

```json
{
  "reqs": [ /* requirements that succeeded */ ],
  "failed": [ "#99: requirement not found" ]
}
```

If `failed` is not empty, the command also prints `error: N requirement(s) failed` to stderr and exits with status 1. Always check both.

`add` is different: it returns one requirement object for a single title and an array for several (from `--stdin`, a pipe or a multi-line argument). It stops at the first error; titles before it are already captured.

## Errors

Errors are written to stderr as `error: <message>` with exit status 1; stdout stays empty or holds the partial batch result. Common messages:

| Message | Meaning |
|---|---|
| `not initialized yet; run: jot init` | The store does not exist |
| `requirement not found` | No requirement with that ID |
| `project "x" is not registered` | Register it with `jot project add` first |
| `unknown state "x"` | Use one of the five states |
