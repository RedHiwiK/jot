# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-10-20

First open-source release.

### Added

- `jot` CLI: capture (`add`, `--stdin`), query (`ls`, `show`, `body`, `path`), edit (`set`, `body set`, `edit`, `triage`), workflow (`mv`, `rm`, `purge`), tags (`tag`, `untag`, `tag ls/rename/rm`), PR/MR links (`link`, `unlink`), projects (`project add/ls/rename/rm/set`), `config` and `sync`. Every data command supports `--json`.
- Five requirement states: `inbox`, `in_progress`, `on_hold`, `done`, `archived`, with a full transition log.
- Project inference from the current Git repository (worktrees included); optional project color and repository URL, inferred from the `origin` remote when not set.
- Local store in `~/.jot` (or `$JOT_HOME`): SQLite metadata and one Markdown file per requirement.
- Jot.app for macOS 14+: board with drag and drop, project navigation, tag filtering, Markdown detail and editing, linked PRs, global search, English and Simplified Chinese, light and dark themes, customizable shortcuts. It bundles its matching CLI.
- Agent skill (`skills/jot/SKILL.md`) for Claude Code, Codex and other agents.
- Release archives: CLI binaries for macOS and Linux (arm64, amd64) and a universal macOS app.
