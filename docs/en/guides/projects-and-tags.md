---
title: Projects and tags
description: Organize requirements with optional projects, free-form tags and triage.
group: guides
order: 2
---

Projects answer "where does this belong?"; tags answer "what is it about?" A requirement has at most one project and any number of tags.

## Projects

A project is a named category with a path, usually a Git repository. You rarely create one by hand: the first capture inside a repository registers it, named after the repository directory. If that name is taken, the parent directory is appended (`api-work`, `api-personal`).

```bash
jot project ls
jot project add notes ~/Documents/notes      # any folder works, Git or not
jot project rename myapp my-app
jot project rm my-app
```

`project rm` only removes the category. Every requirement in it, including done and archived ones, becomes project-less with its state and body intact. No repository or file is deleted. Capturing inside that repository later registers it again; use `jot add --unfiled` to avoid that.

### Moving requirements

```bash
jot set 42 --project myapp
jot set 42 --project ""          # make it project-less
```

The Markdown file moves to the new project's directory under `~/.jot/reqs/`.

### Display settings

```bash
jot project set myapp --color blue                            # red, orange, yellow, green, teal, blue, purple, gray; "" clears
jot project set myapp --repo-url https://github.com/o/myapp   # "" falls back to the Git remote
```

The color only tints the project's folder icon in the app sidebar; cards always use status colors. The repository URL is inferred from the `origin` remote unless set.

The app's **Settings → Projects** page can also reorder, rename and remove projects and set the repository URL.

## Triage

Triage fills in missing projects for requirements captured outside a repository:

```bash
jot triage 42 43 44
jot triage 42 43 --project myapp
```

Without `--project`, an existing project is kept; otherwise Jot tries the directory where the requirement was captured, then the current directory. Triage never changes state. Results come back per requirement; failures are listed and make the command exit non-zero.

## Tags

Tags are free-form labels: release versions (`v1.2`), themes (`bug`, `perf`), anything.

```bash
jot tag 42 v1.2                 # add, keeping existing tags
jot tag 42 43 44 v1.2           # several requirements at once
jot untag 42 v1.2
jot tag 42 --clear
jot set 42 --tags v1.2,bug      # replace all tags
```

Rules:

- Tags are lower-cased and a leading `#` is dropped: `#V1.2` and `v1.2` are the same tag.
- Letters, digits and `. _ / -` are kept; spaces and commas separate tags.
- Leading all-digit arguments are requirement IDs, so pass an all-digit tag with `--tag`: `jot tag 42 --tag 2026`.
- There is no tag registry. A tag exists while at least one requirement carries it.

### Managing tags

```bash
jot tag ls                      # every tag in use, with counts
jot tag rename v1.2 v1.2.1
jot tag rm v1.2                 # removes the label everywhere; requirements stay
```

## Filtering

```bash
jot ls --project myapp
jot ls --tag v1.2 --tag bug         # both tags (AND)
jot ls --tag-any v1.2,v1.3          # either tag (OR)
jot ls --untagged
jot ls --tag v1.2 --all             # include done and archived
```

In the app, click a tag on a requirement to see the active requirements carrying it.
