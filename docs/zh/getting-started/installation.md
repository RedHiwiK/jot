---
title: 安装
description: 安装 macOS App、CLI 和 agent skill。
group: getting-started
order: 2
---

Jot 由三部分组成，可以分别安装：macOS App（内置 CLI）、单独的 CLI，以及 agent skill。

## 让 agent 帮你安装

把下面这段话粘贴给 Claude Code、Codex 或其他 coding agent：

```text
Install the jot CLI and its skill by following https://github.com/RedHiwiK/jot/blob/main/docs/en/guides/ai-agents.md
```

## macOS App

需要 macOS 14 或更高版本，支持 Apple silicon 和 Intel。

```bash
curl -fsSLO https://github.com/RedHiwiK/jot/releases/latest/download/Jot_macos.zip
ditto -x -k Jot_macos.zip /Applications
xattr -dr com.apple.quarantine /Applications/Jot.app
```

App 使用 ad-hoc 签名，未经过公证（notarize），所以 Gatekeeper 会拦截首次启动。`xattr` 命令用于移除隔离标记；也可以右键点击 Jot.app，选择**打开**一次。

App 内置了版本匹配的 CLI。把它加入 `PATH`，就能在终端里使用同一个二进制：

```bash
mkdir -p ~/.local/bin
ln -sf /Applications/Jot.app/Contents/Helpers/jot ~/.local/bin/jot
```

## 仅安装 CLI

支持 macOS 或 Linux，arm64 或 amd64。

使用 Go 1.27 或更高版本：

```bash
go install github.com/RedHiwiK/jot/cmd/jot@latest
```

或者使用发布包：

```bash
os=$(uname -s | tr A-Z a-z); arch=$(uname -m)
[ "$arch" = x86_64 ] && arch=amd64; [ "$arch" = aarch64 ] && arch=arm64
curl -fsSL "https://github.com/RedHiwiK/jot/releases/latest/download/jot_${os}_${arch}.tar.gz" | tar -xz -C /tmp
mkdir -p ~/.local/bin && mv "/tmp/jot_${os}_${arch}/jot" ~/.local/bin/jot
```

每个发布包里还附带 `skills/jot/SKILL.md`。

## 检查二进制

macOS 自带一个无关的 `/usr/bin/jot`，它会输出连续数字。请把 `~/.local/bin`（或你的 Go bin 目录）放在 `PATH` 中 `/usr/bin` 之前，然后检查：

```bash
jot --version
# jot version 0.1.0
```

如果输出的是数字，请参见[故障排查](../help/troubleshooting.md#jot-输出的是数字)。

## 初始化数据目录

```bash
jot init
```

这会创建 `~/.jot`。设置 `JOT_HOME` 可以改用其他目录，参见[配置](../reference/configuration.md)。

## Agent skill

```bash
# Claude Code
mkdir -p ~/.claude/skills/jot
curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.claude/skills/jot/SKILL.md

# Codex
mkdir -p ~/.codex/skills/jot
curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.codex/skills/jot/SKILL.md
```

更多方式，包括不支持 skill 的 agent，参见 [AI agent](../guides/ai-agents.md)。

## 从源码构建

需要 Go 1.27+；构建 App 还需要 Swift 6 和 macOS 14+。

```bash
git clone https://github.com/RedHiwiK/jot.git && cd jot
make install       # CLI 安装到 ~/.local/bin/jot
make install-app   # Jot.app 安装到 /Applications
```

## 卸载

```bash
rm -rf /Applications/Jot.app ~/.local/bin/jot ~/.claude/skills/jot ~/.codex/skills/jot
rm -rf ~/.jot      # 会删除所有需求；不确定的话先备份
```
