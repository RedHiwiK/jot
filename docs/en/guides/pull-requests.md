---
title: Pull requests
description: Bind pull and merge requests to requirements.
group: guides
order: 6
---

When a requirement turns into code, bind the pull or merge request to it. The link shows up in JSON, in the Markdown frontmatter and on the requirement's page in the app.

```bash
jot link 42 https://github.com/owner/repo/pull/12
jot link 42 https://gitlab.example.com/group/repo/-/merge_requests/7
jot unlink 42 https://github.com/owner/repo/pull/12
jot unlink 42 --all
```

`link` is incremental: binding a second PR keeps the first. Links are listed in the order they were bound. Jot stores the URL only; it never contacts the host.

## Referring to requirements

In PR titles, descriptions and commit messages, write `JOT-42`. A bare `#42` is turned into a link to issue or PR 42 by GitHub and GitLab.

```text
fix(search): query the index instead of the table (JOT-42)
```

## With an agent

The skill tells agents to run `jot link <id> <url>` right after opening a PR for a requirement, and to use the `JOT-<id>` form in the PR text.
