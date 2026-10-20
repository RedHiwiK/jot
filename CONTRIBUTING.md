# Contributing

Thanks for your interest in Jot. Bug reports, documentation fixes and pull requests are welcome.

## Before you start

- For bugs, open an issue with `jot --version`, what you did, what you expected and what happened.
- For new features, open an issue first to agree on the approach. Jot aims to stay small: one local store, one CLI that owns every rule, a thin native app.
- Use a throwaway store while experimenting: `export JOT_HOME=$(mktemp -d)`.

## Development setup

Requirements: Go 1.27+, Swift 6 and macOS 14+ for the app (the CLI builds and tests on Linux too).

```bash
git clone https://github.com/RedHiwiK/jot.git
cd jot
make build                 # bin/jot
macos/build-app.sh debug   # macos/build/Jot.app with the matching CLI
```

[AGENTS.md](AGENTS.md) has the repository map and conventions.

## Tests

```bash
make test    # go vet ./..., go test ./..., swift test
```

Add tests for rule changes in the CLI (states, tags, project inference, JSON output). For app changes, describe in the pull request what you checked by hand: window sizes, light and dark themes, English and Chinese.

## Pull requests

- Keep each pull request focused; run `gofmt` and `make test` before pushing.
- Program-generated text (CLI output, help, the skill) is English. App UI strings go through `macos/Sources/Jot/i18n/Strings.swift` with both English and Chinese.
- Update the docs and `CHANGELOG.md` (under Unreleased) when behavior changes.

## Releasing

1. Set `Version` in `internal/cli/root.go` and move the Unreleased notes in `CHANGELOG.md` under the new version.
2. Commit, then tag and push: `git tag v0.2.0 && git push origin v0.2.0`.
3. The Release workflow checks that the tag matches `Version`, runs the tests, builds the archives with `scripts/dist.sh` and publishes the GitHub release with the changelog section as notes.
