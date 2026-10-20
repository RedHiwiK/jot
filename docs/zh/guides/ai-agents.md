---
title: AI agent
description: 配置 Claude Code、Codex 等 agent，让它们帮你录入和整理需求。
group: guides
order: 5
---

Jot 的设计目标是既能由人使用，也能由 coding agent 驱动。agent 需要两样东西：`jot` CLI（其 `--json` 输出是稳定的契约），以及告诉它何时、如何调用 CLI 的 skill 文件。

## agent 可以照着做的安装步骤

1. **安装 CLI**（macOS 或 Linux）：

   ```bash
   os=$(uname -s | tr A-Z a-z); arch=$(uname -m)
   [ "$arch" = x86_64 ] && arch=amd64; [ "$arch" = aarch64 ] && arch=arm64
   curl -fsSL "https://github.com/RedHiwiK/jot/releases/latest/download/jot_${os}_${arch}.tar.gz" | tar -xz -C /tmp
   mkdir -p ~/.local/bin && mv "/tmp/jot_${os}_${arch}/jot" ~/.local/bin/jot
   ```

   也可以用 Go 安装：`go install github.com/RedHiwiK/jot/cmd/jot@latest`。

2. **检查二进制。** macOS 自带一个无关的 `/usr/bin/jot`；`PATH` 中 `~/.local/bin` 必须排在 `/usr/bin` 之前。

   ```bash
   jot --version     # 预期输出：jot version 0.1.0
   ```

3. **初始化**，只需一次：`jot init`。

4. **安装 skill**：

   ```bash
   # Claude Code
   mkdir -p ~/.claude/skills/jot
   curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.claude/skills/jot/SKILL.md

   # Codex
   mkdir -p ~/.codex/skills/jot
   curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.codex/skills/jot/SKILL.md
   ```

   如果有本地 clone，可以改用符号链接，这样更新会随 `git pull` 同步：`ln -s "$PWD/skills/jot" ~/.claude/skills/jot`。

5. **不支持 skill 的 agent**（Cursor 等）：把 [`SKILL.md`](https://github.com/RedHiwiK/jot/blob/main/skills/jot/SKILL.md) 的内容粘贴到项目规则中（`AGENTS.md`、`CLAUDE.md`、`.cursor/rules`）。

完整文档也提供了供 agent 读取的单文件版本：[`llms-full.txt`](https://kunkunred.hiwik.cn/en/projects/jot/llms-full.txt)。

## 怎么说

| 你说 | agent 执行 |
|---|---|
| "记一下：搜索很慢" | `jot add "Search is slow" --note "..."` |
| "我手上有什么事？" | `jot ls --json`，然后给出简短总结 |
| "myapp 还剩什么？" | `jot ls --project myapp --json` |
| "整理一下收件箱" | `jot ls --state inbox --json`、`jot triage ...`、`jot tag ...` |
| "把这几条标成 v1.2" | `jot tag 42 43 44 v1.2` |
| "把 42 标记为完成" | `jot mv 42 done --json` |
| "v1.2 我们发了什么？" | `jot ls --tag v1.2 --all --json` |
| （为 42 提交 PR 之后） | `jot link 42 <pr-url>`，并在 PR 标题中写 `JOT-42` |

## skill 的行为

- 录入时不会追问项目或优先级，用一行话概括回执，然后回到原来的任务。
- 除非你要求，否则不会开始实现某条需求。
- 总结 JSON 内容，而不是原样贴出。
- 批量操作失败时如实报告（`failed` 和退出码），不会把部分成功说成成功。
- 除非你明确要求永久删除，否则绝不执行 `jot purge`。
- 遵循 `JOT_HOME`，也不会修改其他工具的配置。

## 脚本和 agent 的调用约定

- 凡是要解析的输出都使用 `--json`，参见 [JSON 输出](../reference/json-output.md)。
- 退出码 `0` 表示成功。批量命令返回 `{reqs, failed}`，只要有任何失败就以非零退出码退出。
- 错误以 `error: ...` 的形式写到 stderr。
- 用 `JOT_HOME` 指定数据目录，可以让测试和试验不碰真实数据。
