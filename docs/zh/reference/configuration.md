---
title: 配置
description: 环境变量、编辑器设置和 App 偏好设置。
group: reference
order: 4
---

Jot 有意把可配置项压到很少。

## 环境变量

| 变量 | 作用 |
|---|---|
| `JOT_HOME` | 用此目录代替 `~/.jot` 作为数据目录。适用于测试、演示和独立的数据目录。App 会把它传给自己的 CLI。 |
| `EDITOR` | 未配置编辑器时，`jot edit` 使用的编辑器 |
| `NO_COLOR` | 关闭 CLI 的彩色输出 |

## 编辑器

```bash
jot config set editor nano      # 可执行文件名或路径
jot config get editor
jot config ls --json
jot config set editor ""        # 恢复为 $EDITOR，再回退到 vi
```

该设置存放在数据库中，因此会跟随 `JOT_HOME` 所指向的数据目录。

## App 偏好设置

语言、主题、快捷键、侧栏顺序和窗口大小是 App 的 macOS 偏好设置（`io.github.redhiwik.jot`），在 App 的设置中修改。自定义主题放在 `~/.jot/themes/*.json`，参见 [macOS App](../guides/macos-app.md#自定义主题)。

## Shell 补全

```bash
jot completion zsh > "${fpath[1]}/_jot"     # zsh
jot completion bash > /usr/local/etc/bash_completion.d/jot
jot completion fish > ~/.config/fish/completions/jot.fish
```
