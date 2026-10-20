---
title: CLI reference
description: Every jot command and flag.
group: reference
order: 1
---

`jot` is the single source of truth for every write: the macOS app and the agent skill both call it. Every command that reads or writes data accepts `--json` for machine-readable output ([JSON output](./json-output.md)); without it, output is a short human-readable receipt.

Run `jot <command> --help` for the full flag list of any command.

## Setup

```bash
jot init                      # create ~/.jot (or $JOT_HOME)
jot config set editor nano    # editor for `jot edit`; falls back to $EDITOR, then vi
jot config ls --json
```

## Capture

```bash
jot add "Title"
jot add "Title" --note "Context, conclusion or acceptance criteria"
jot add "Title" --project myapp
jot add "Personal task" --unfiled
jot add "Title" --tag v0.2 --tag bug
jot add --stdin < titles.txt          # one requirement per line
```

New requirements start in `inbox`. Without `--project`, the project is inferred from the current directory: inside a Git repository the repository is registered as a project automatically (named after its directory); elsewhere the requirement stays project-less. `--unfiled` skips inference.

A single `add --json` returns one requirement object; several titles (from `--stdin`, a pipe or a multi-line argument) return an array. `add` stops at the first error, keeping the titles captured before it.

## Query

```bash
jot ls                               # active requirements grouped by state
jot ls --all                         # include done and archived
jot ls --state on_hold
jot ls --project myapp
jot ls --tag v0.2 --tag bug          # all of the tags (AND)
jot ls --tag-any v0.2,v0.3           # any of the tags (OR)
jot ls --untagged
jot show 42 --json                   # metadata plus the full body in `note`
jot body 42                          # body without frontmatter
jot path 42                          # absolute path of the Markdown file
```

`ls --json` returns `{reqs, projects, tags, detected_project, cwd}`: the full project and tag lists come with every listing, so a separate `project ls` or `tag ls` call is rarely needed. In `ls`, `note` is the capture note; in `show`, `note` is the whole body.

## Edit

```bash
jot set 42 --title "New title"
jot set 42 --priority 1              # 0 normal, 1 high
jot set 42 --project myapp
jot set 42 --project ""              # make it project-less
jot set 42 --tags v0.2,bug           # replace every tag
jot body set 42 < body.md            # replace the body (Markdown without frontmatter)
jot edit 42                          # open the body in the configured editor
jot triage 42 43 --json              # fill in missing projects
jot triage 42 43 --project myapp --json
```

Changing the project moves the Markdown file to the new project's directory. `triage` keeps an existing project, otherwise tries the directory the requirement was captured in, then the current directory, and never changes state. An explicit `--project` overrides.

## Workflow

```bash
jot mv 42 in_progress
jot mv 42 on_hold
jot mv 42 done
jot mv 42 inbox
jot rm 42                            # archive (recoverable)
jot mv 42 inbox                      # restore an archived requirement
jot purge 42 --yes                   # permanently delete an archived requirement
```

| State | Meaning |
|---|---|
| `inbox` | Captured, not started |
| `in_progress` | Being worked on, including review and acceptance |
| `on_hold` | Deferred or waiting on something external |
| `done` | Finished |
| `archived` | Not going to happen; still searchable and restorable |

State is set by hand (or by an agent the user asked to): it records intent, not whether any process is running. Every transition is recorded in `state_log`.

`purge` only accepts archived requirements and asks for confirmation unless `--yes` is given. It removes the database rows and the Markdown file.

## Tags

```bash
jot tag 42 v0.2                      # add, keeping existing tags
jot tag 42 43 44 v0.2                # several requirements at once
jot tag 42 --tag 2026                # literal value (needed for all-digit tags)
jot untag 42 v0.2
jot tag 42 --clear
jot tag ls --json                    # every tag in use, with counts
jot tag rename v0.2 v0.3
jot tag rm v0.2                      # drop the label everywhere; requirements stay
```

Tags are free-form labels orthogonal to projects: a requirement belongs to at most one project but can carry any number of tags. They are normalized to lower case with a leading `#` dropped, so `#V0.2` and `v0.2` are one tag. Letters, digits and `. _ / -` are kept; spaces and commas separate tags.

In `tag` and `untag`, leading all-digit arguments are read as requirement IDs, so pass an all-digit tag with `--tag`, which cannot be mixed with positional tags. There is no tag registry: a tag exists while some requirement carries it.

## Links

```bash
jot link 42 https://github.com/owner/repo/pull/12
jot unlink 42 https://github.com/owner/repo/pull/12
jot unlink 42 --all
```

Links bind pull/merge request URLs to a requirement. They appear as `links` in requirement JSON, in the frontmatter and on the app's detail page. Nothing is fetched from the host. Refer to requirements as `JOT-42` in PR titles, descriptions and commits; a bare `#42` collides with the host's own numbering.

## Projects

```bash
jot project add myapp ~/code/myapp
jot project ls --json
jot project rename myapp my-app
jot project set myapp --color blue                         # red/orange/yellow/green/teal/blue/purple/gray; "" clears
jot project set myapp --repo-url https://github.com/o/r    # "" falls back to the Git remote
jot project rm myapp --json
```

Projects are optional categories and do not have to be Git repositories. `repo_url` in `project ls --json` is either configured or inferred from the `origin` remote (`repo_url_inferred: true`). The color only tints the project's folder icon in the app sidebar.

`project rm` only removes the category: every requirement in it, including done and archived ones, becomes project-less with its state and body intact. No repository or requirement file is deleted. Capturing again inside that repository registers the project again; use `add --unfiled` to avoid that.

## Batch results and errors

Batch commands (`triage`, `tag`, `untag`) process every item and return `{reqs, failed}` in JSON. Any failure makes the command exit non-zero, so check both the exit code and `failed`.

Errors go to stderr as `error: ...` with exit code 1. `not initialized yet; run: jot init` means the store does not exist.

## Maintenance

```bash
jot sync     # rewrite every frontmatter block from SQLite
```

SQLite and the Markdown files cannot share a transaction. If a command reports that metadata was updated but the body sync failed, run `jot sync`.
