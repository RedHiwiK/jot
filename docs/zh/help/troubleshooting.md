---
title: 故障排查
description: 常见安装和使用问题的解决办法。
group: help
order: 1
---

## `jot` 输出的是数字

macOS 自带 `/usr/bin/jot`，这是一个无关的工具，会输出连续数字，而且它排在你安装的 `jot` 之前被找到。先确认实际运行的是哪一个：

```bash
which -a jot
```

把你的安装目录放到 `PATH` 最前面，例如写进 `~/.zshrc`：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

然后打开新终端，运行 `jot --version`，应输出 `jot version ...`。

## "无法打开 Jot.app"

App 使用 ad-hoc 签名且未经过公证，所以 Gatekeeper 会拦截下载得到的 App。执行一次下面的命令移除隔离标记：

```bash
xattr -dr com.apple.quarantine /Applications/Jot.app
```

或者在 Finder 中右键点击 Jot.app，选择**打开**，然后确认。

## `not initialized yet; run: jot init`

数据目录还不存在。运行 `jot init`。如果你使用了 `JOT_HOME`，请确认它设置在同一个 shell 里（对 agent 来说，则是设置在它们的环境中）。

## App 提示 "jot not found"

App 找不到内置的 CLI，在备用路径中也没找到任何 CLI。请用发布的 zip 重新安装 App，或把 CLI 安装到 `~/.local/bin/jot`。

## App 没有显示在终端里做的改动

App 每 15 秒刷新一次。按 <kbd>⌘R</kbd> 可立即刷新。如果改动仍未出现，请确认终端和 App 使用的是同一个数据目录：在 shell 里设置的 `JOT_HOME` 不会传给从 Dock 启动的 App。

## "metadata updated, but body sync failed"

SQLite 和 Markdown 文件无法在同一个事务里修改。元数据的变更已经保存；运行 `jot sync`，按数据库中的数据重写所有正文的 frontmatter。

## 需求被归到了错误的项目

```bash
jot set 42 --project correct-name
jot set 42 --project ""           # 或者改成无项目
```

要阻止某个仓库被注册，可以在录入时加 `--unfiled`，或用 `jot project rm` 删除该项目（需求会保留）。

## 迁移到新 Mac

把 `~/.jot` 复制到新 Mac 上的相同位置，然后安装 App 和 CLI。所有内容——需求、历史、项目、标签、链接和自定义主题——都在这个目录里。

## 仍然没解决

到 [github.com/RedHiwiK/jot/issues](https://github.com/RedHiwiK/jot/issues) 提交 issue，请附上 `jot --version` 的输出、你执行的操作以及出现的现象。
