---
title: Troubleshooting
description: Fixes for common installation and usage problems.
group: help
order: 1
---

## `jot` prints numbers

macOS ships `/usr/bin/jot`, an unrelated tool that prints sequential numbers, and it is found before yours. Check which one runs:

```bash
which -a jot
```

Put your install directory first in `PATH`, for example in `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then open a new terminal and run `jot --version`; it should print `jot version ...`.

## "Jot.app can't be opened"

The app is ad-hoc signed and not notarized, so Gatekeeper blocks downloads of it. Remove the quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/Jot.app
```

Or right-click Jot.app in Finder, choose **Open**, then confirm.

## `not initialized yet; run: jot init`

The store does not exist yet. Run `jot init`. If you use `JOT_HOME`, make sure it is set in the same shell (and for agents, in their environment).

## The app says "jot not found"

The app could not find its bundled CLI or any CLI on the fallback paths. Reinstall the app from the release zip, or install the CLI to `~/.local/bin/jot`.

## The app does not show a change made in the terminal

The app refreshes every 15 seconds. Press <kbd>⌘R</kbd> to refresh now. If the change still does not appear, check that the terminal and the app use the same store: a `JOT_HOME` set in your shell does not reach an app launched from the Dock.

## "metadata updated, but body sync failed"

SQLite and the Markdown files cannot change in one transaction. The metadata change was saved; run `jot sync` to rewrite the frontmatter of every body from the database.

## A requirement went to the wrong project

```bash
jot set 42 --project correct-name
jot set 42 --project ""           # or make it project-less
```

To stop a repository from being registered, capture with `--unfiled`, or remove the project with `jot project rm` (requirements are kept).

## Moving to a new Mac

Copy `~/.jot` to the same place on the new Mac, then install the app and CLI. Everything — requirements, history, projects, tags, links and custom themes — lives in that directory.

## Still stuck

Open an issue at [github.com/RedHiwiK/jot/issues](https://github.com/RedHiwiK/jot/issues) with `jot --version`, what you ran and what happened.
