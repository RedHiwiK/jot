---
title: Files and data
description: What Jot stores where, the Markdown format and the SQLite tables.
group: reference
order: 3
---

Everything lives in one directory, `~/.jot` by default or `$JOT_HOME` when set:

```
~/.jot/
├── jot.db                       SQLite (WAL): metadata, state history, tags, links, settings
├── themes/                      optional custom app themes (*.json)
└── reqs/
    ├── _inbox/                  project-less requirements
    │   └── 0007-2026-10-20-Plan-the-weekend.md
    └── myapp/
        └── 0042-2026-10-18-Search-page-is-slow.md
```

Back up the whole directory. Nothing outside it is read or written, apart from `.git/config` of registered projects to infer their web URL.

## Markdown bodies

Markdown is authoritative for the body. The frontmatter is a readable copy of the SQLite metadata, rewritten by the CLI on every change:

```markdown
---
id: 42
title: "Search page is slow"
state: in_progress
project: "myapp"
tags: [v0.2, perf]
created: 2026-10-18T09:12:44+08:00
---

## Requirement

Search page is slow

## Acceptance criteria

- [ ] 

## Notes

Traced to a direct DB query inside onChange
```

The three headings are a fixed file format, like the frontmatter keys. Content under them is stored as typed, in any language. Edit the body with `jot edit`, `jot body set` or the app; editing the file directly also works, but change metadata only through the CLI, because `jot sync` rewrites the frontmatter from SQLite.

## SQLite tables

| Table | Contents |
|---|---|
| `reqs` | ID, title, body path, state, optional project, priority, capture directory and note, created/updated/started/done timestamps |
| `projects` | Name, path, optional color and repository URL |
| `state_log` | Every state transition: from, to, actor, time |
| `req_tags` | `(req_id, tag)` pairs; the tag list is a `SELECT DISTINCT`, so unused tags disappear on their own |
| `req_links` | `(req_id, url)` pairs in binding order |
| `meta` | Settings such as the editor |

The schema is in [`internal/store/schema.sql`](https://github.com/RedHiwiK/jot/blob/main/internal/store/schema.sql). The app never opens the database directly: it calls the bundled CLI and decodes its JSON, so state rules, project inference and frontmatter sync exist in one place.

## Consistency

Body writes are atomic (write to a temporary file, then rename). SQLite and files cannot share a transaction: when a file operation fails after the metadata changed, the command reports it and `jot sync` repairs the frontmatter. Project removal rolls back when moving bodies fails.
