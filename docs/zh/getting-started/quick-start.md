---
title: 快速上手
description: 五分钟内录入、整理并完成你的第一批需求。
group: getting-started
order: 3
---

本教程假定 CLI 已安装，且 `jot --version` 能输出 `jot version ...`。如果不想动真实的数据目录，可以先执行 `export JOT_HOME=$(mktemp -d)`。

## 1. 初始化

```bash
jot init
```

## 2. 在仓库中录入

```bash
cd ~/code/myapp
jot add "Search page is slow" --note "Traced to a DB query inside onChange"
# ✓ #1 captured into INBOX  myapp
```

由于你在 Git 仓库里，Jot 自动把它注册为项目 `myapp`，并把需求归入其中，全程没有任何询问。

## 3. 录入个人事项

```bash
jot add "Renew the developer certificate" --unfiled
```

`--unfiled` 会跳过项目推断。在仓库之外录入的需求本来就没有项目。

## 4. 打标签并列出

```bash
jot tag 1 v1.2 bug
jot ls
```

```text
INBOX (2)
  #2    Renew the developer certificate    —        just now
  #1    Search page is slow                myapp    just now  bug v1.2
```

## 5. 推进状态

```bash
jot mv 1 in_progress
jot mv 1 done
jot ls --all
```

## 6. 查看和编辑正文

```bash
jot show 1        # 元数据和 Markdown 正文
jot edit 1        # 在编辑器中打开正文
```

每条需求都是 `~/.jot/reqs/` 下的一个 Markdown 文件，参见[文件与数据](../reference/data-model.md)。

## 7. 打开 App

启动 Jot.app。看板显示收件箱、进行中和暂缓三列；可以在列之间拖动卡片，双击标题重命名，按 <kbd>⌘F</kbd> 搜索。参见 [macOS App](../guides/macos-app.md)。

## 8. 交给 agent

安装 [skill](../guides/ai-agents.md) 之后，直接对话即可："记一下：窗口较小时导出按钮被隐藏了""myapp 里我还有什么要做？""把 1 标记为完成"。

## 下一步

- 深入了解[录入需求](../guides/capturing.md)
- [CLI 参考](../reference/cli.md)
