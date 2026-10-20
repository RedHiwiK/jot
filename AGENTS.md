# AGENTS.md

Guidance for AI agents working on this repository. To use Jot for managing requirements, read [docs/en/guides/ai-agents.md](docs/en/guides/ai-agents.md) and [skills/jot/SKILL.md](skills/jot/SKILL.md) instead.

## Repository map

| Path | Contents |
|---|---|
| `cmd/jot/` | CLI entry point |
| `internal/cli/` | Cobra commands, human and JSON output (`jsonout.go`) |
| `internal/store/` | SQLite schema (`schema.sql`), requirements, projects and Git discovery, tags, links, Markdown bodies |
| `internal/model/` | States, requirement and project types, body path naming |
| `macos/` | SwiftUI app (SwiftPM package `Jot`), `build-app.sh`, icon in `Resources/` |
| `macos/Sources/Jot/i18n/Strings.swift` | Every UI string, English and Simplified Chinese |
| `macos/Sources/Jot/Theme/` | Color and spacing tokens |
| `skills/jot/SKILL.md` | The agent skill shipped to users |
| `docs/en/`, `docs/zh/` | User documentation, one file per page with `title`/`description`/`group`/`order` frontmatter; rendered at kunkunred.hiwik.cn/projects/jot/docs/ |
| `docs/images/` | Images shared by both languages |
| `scripts/dist.sh` | Release archives |

## Commands

```bash
make build                    # bin/jot
make test                     # go vet + go test + swift test
go test ./internal/...        # CLI and store only
cd macos && swift test        # app only
macos/build-app.sh debug      # macos/build/Jot.app with the matching CLI
scripts/dist.sh               # dist/: CLI archives, universal app zip, checksums
```

Always run against a temporary store (`export JOT_HOME=$(mktemp -d)`); never mutate `~/.jot` while testing.

## Architecture rules

- The CLI owns every rule (state transitions, project inference, tag normalization, frontmatter sync). The app calls the bundled CLI through `JotClient` and decodes its JSON; it never opens SQLite. New behavior goes into the CLI first, then the app.
- The JSON in `internal/cli/jsonout.go` is a contract with the app (`macos/Sources/Jot/Models.swift`) and with agents. Add fields rather than rename or remove them, and keep both sides in sync.
- Markdown is authoritative for bodies; frontmatter is a copy of SQLite metadata. Body writes must stay atomic.
- `schema.sql` uses `CREATE ... IF NOT EXISTS`. A new column on an existing table needs an explicit migration in `store.Open`.

## Language

- Program-generated text is English only: CLI help, errors and receipts, `skills/**/SKILL.md`, and the Markdown body headings (`## Requirement` / `## Acceptance criteria` / `## Notes`, a file format like the frontmatter keys). Do not add a localized skill.
- User-entered content (titles, `--note`, bodies) is stored as typed and never translated.
- Code comments, commit messages and pull requests are English. The app localizes UI text only through `Strings.swift`.
- User docs exist in English (`docs/en/`, the source) and Simplified Chinese (`docs/zh/`) with identical paths. A behavior change updates both in the same pull request; UI names in the Chinese docs match the zh-Hans strings in `Strings.swift`.
- Docs links are relative Markdown file links (`../reference/cli.md`) so they work on GitHub and on the docs site.
- Comments explain why the code is written this way or what must not be done; no change history or references to design documents.

## App design rules

- Boards, cards, list rows and group headers use status colors only. A project's color tints only its folder icon in the sidebar: no project dots, stripes or backgrounds on cards and rows.
- Low-frequency settings (project color, repository URL) are set through the CLI or the skill; the app displays them without a settings entry.
- Use theme tokens from `Theme/`, never hard-coded colors. Capture stays in the CLI and skill; the app has no creation form.

## Tests

- CLI and store rules (states, tags, project inference, JSON shape) get Go tests next to the code.
- App logic that can run without UI (decoding, navigation, filtering, shortcuts) gets Swift Testing tests in `macos/Tests/JotTests`.
- UI changes are checked by hand; describe what you checked.

## Public repository hygiene

This repository is public. Everything committed, pushed or attached to a release is published.

- No personal or workplace identifiers: real names, personal email addresses, employer or internal project names, local absolute paths, hostnames, tokens. Examples use neutral names (`myapp`, `pawprint`, `~/code/myapp`, `owner/repo`).
- Never copy content from a real store (`~/.jot`): requirement titles, project names and tags in tests, docs and screenshots are made up. Screenshots come from a throwaway `JOT_HOME` with fictional data.
- Strip image metadata before committing (`exiftool -all= <file>`): screenshots carry display profiles and capture notes.
- Commit with the GitHub noreply identity; never add co-author or signature lines that expose other identities.
- Published history is never rewritten: no force pushes, amends of pushed commits or tag moves. Fix mistakes with a new commit; if something sensitive was pushed, stop and rotate or remove it with the owner's approval.
- Never commit `dist/`, build products, local stores (`*.db`) or `.env` files.

## Releases

`Version` in `internal/cli/root.go` is the single version source; the app bundle reads it at build time. Pushing a tag `v<Version>` runs `.github/workflows/release.yml`. See [CONTRIBUTING.md](CONTRIBUTING.md#releasing).
