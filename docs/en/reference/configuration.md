---
title: Configuration
description: Environment variables, the editor setting and app preferences.
group: reference
order: 4
---

Jot has very little to configure on purpose.

## Environment variables

| Variable | Effect |
|---|---|
| `JOT_HOME` | Store directory instead of `~/.jot`. Useful for tests, demos and separate stores. The app passes it through to its CLI. |
| `EDITOR` | Editor for `jot edit` when no editor is configured |
| `NO_COLOR` | Disable colored CLI output |

## Editor

```bash
jot config set editor nano      # an executable name or path
jot config get editor
jot config ls --json
jot config set editor ""        # back to $EDITOR, then vi
```

The setting is stored in the database, so it follows the store selected by `JOT_HOME`.

## App preferences

Language, theme, shortcuts, sidebar order and window sizes are macOS preferences of the app (`io.github.redhiwik.jot`), changed in the app's Settings. Custom themes live in `~/.jot/themes/*.json`; see [The macOS app](../guides/macos-app.md#custom-themes).

## Shell completion

```bash
jot completion zsh > "${fpath[1]}/_jot"     # zsh
jot completion bash > /usr/local/etc/bash_completion.d/jot
jot completion fish > ~/.config/fish/completions/jot.fish
```
