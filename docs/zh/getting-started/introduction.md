---
title: 简介
description: Jot 是什么、适合谁用，以及各部分如何配合。
group: getting-started
order: 1
---

Jot 是一个本地需求看板，面向个人和他的 AI agent。工作中冒出来的需求、想法和待办——"搜索页很慢""v1.2 加上 GPX 导出""续签证书"——都可以记在这里，并从收件箱一路推进到已完成。

![The Jot board](../../images/board.png)

## 为什么用 Jot

这类想法多半出现在别的工作中间：在终端里、在代码评审时、在和 coding agent 对话时。打开 issue 跟踪工具的成本比这个想法本身还高，于是它们就丢了。Jot 让记录比遗忘更省事：

- **一行记下。** 在任意目录执行 `jot add "Search page is slow"`，或者对 agent 说"记一下"。
- **自动归类。** 在 Git 仓库里，需求会直接归入该仓库对应的项目，不会追问。
- **看板呈现进度。** 原生 macOS App 展示收件箱、进行中和暂缓的内容。
- **数据在你手里。** 无需账号、服务器或同步服务：一个 SQLite 文件，外加每条需求一个 Markdown 文件。

## 组成部分

| 组成 | 作用 |
|---|---|
| `jot` CLI | 唯一写入数据的入口。所有命令都支持 `--json` 输出，供脚本和 agent 使用。 |
| Jot.app | 基于 SwiftUI 的 macOS 14+ 看板。它调用内置的 CLI，因此与 CLI 的行为始终一致。 |
| Agent skill | 一个 `SKILL.md`，告诉 Claude Code、Codex 等 agent 何时、如何调用 CLI。 |
| `~/.jot` | 数据目录：`jot.db` 存放元数据和历史，`reqs/` 存放 Markdown 正文。 |

## 概念

- **需求（Requirement）**：一件待办的事，包含标题、可选的 Markdown 正文、状态、可选的项目，以及任意数量的标签。
- **状态（State）**：`inbox`、`in_progress`、`on_hold`、`done` 或 `archived`。状态记录的是意图，由你或你委托的 agent 设置。参见[工作流](../guides/workflow.md)。
- **项目（Project）**：可选的分类，通常对应一个 Git 仓库，首次录入时自动注册。参见[项目与标签](../guides/projects-and-tags.md)。
- **标签（Tag）**：自由格式的标记，如 `v1.2` 或 `bug`，与项目相互独立。
- **链接（Link）**：绑定到需求上的 pull request 或 merge request。参见[Pull request](../guides/pull-requests.md)。

## 下一步

- [安装 Jot](./installation.md)
- [五分钟快速上手](./quick-start.md)
- [在 AI agent 中使用 Jot](../guides/ai-agents.md)
