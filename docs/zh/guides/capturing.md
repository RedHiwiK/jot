---
title: 录入需求
description: 通过终端、脚本和 agent 把需求记进 Jot。
group: guides
order: 1
---

录入的成本应该比遗忘更低。`jot add` 不会追问任何事：项目自动推断，状态为 `inbox`，其余内容以后再补。

## 录入一条需求

```bash
jot add "Search page is slow"
jot add "Search page is slow" --note "Traced to a DB query inside onChange"
```

标题会成为列表中的条目。`--note` 写入 Markdown 正文的 **Notes** 部分，适合放背景、讨论得出的结论或验收标准。标题和备注按输入原样保存，任何语言都可以。

## 归入哪个项目

| 情形 | 结果 |
|---|---|
| 在 Git 仓库内（或其 worktree 内） | 归入该仓库对应的项目，首次使用时自动注册 |
| `--project myapp` | 归入 `myapp`，该项目必须已注册 |
| `--unfiled` | 无项目，即使在仓库内也一样 |
| 其他任意目录 | 无项目 |

录入时所在的目录会记为 `origin_cwd`，以便之后通过[归类](./projects-and-tags.md#归类)补上项目。

## 录入时打标签

```bash
jot add "Ship the new board" --tag v1.2 --tag ui
jot add "Ship the new board" --tag v1.2,ui
```

## 批量录入

```bash
jot add --stdin < ideas.txt
printf '%s\n' "Dark mode contrast" "Export as GPX" | jot add --stdin --tag v1.3
```

每个非空行对应一条需求；不带 `--stdin` 直接通过管道传给 `jot add` 也可以，多行的标题参数同样可以。加上 `--json` 时，多个标题会返回一个数组。录入遇到第一个错误就会停止，此前的行已经保留。

## 通过 agent 录入

装好 [skill](./ai-agents.md) 后，直接说"记一下：……"或"加一条需求：……"。agent 会用一段概括对话内容的简短 `--note` 来录入，用一行话汇报回执，然后回到原来的工作。它不会开始实现这条需求。

## 正文

每条需求都有一个 Markdown 文件，包含三个部分：

```markdown
## Requirement

Search page is slow

## Acceptance criteria

- [ ] 

## Notes

Traced to a DB query inside onChange
```

可以用 `jot edit 42` 编辑，用 `jot body set 42 < body.md` 替换，或使用 App 里的编辑器。参见[文件与数据](../reference/data-model.md)。

## 好习惯

- 标题写成你想要的结果（"搜索在 200 ms 内返回"），而不是活动本身。
- 先记下，后整理；收件箱本来就可以乱。
- 把手头已有的依据写进 `--note`，这正是你以后最容易想不起来的部分。
