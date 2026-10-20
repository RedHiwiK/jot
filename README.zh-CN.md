<p align="center">
  <img src="macos/Resources/AppIcon-1024.png" width="128" height="128" alt="Jot 图标">
</p>

<h1 align="center">Jot</h1>

<p align="center"><strong>给一个人和他的 AI agent 用的本地需求看板：在终端或对话里随手记，在原生 macOS 看板上推进度。</strong></p>

<p align="center">
  <a href="https://github.com/RedHiwiK/jot/actions/workflows/ci.yml"><img src="https://github.com/RedHiwiK/jot/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/RedHiwiK/jot/releases/latest"><img src="https://img.shields.io/github/v/release/RedHiwiK/jot?include_prereleases" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Go-1.27-00ADD8?logo=go&logoColor=white" alt="Go 1.27">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2EA44F" alt="License MIT"></a>
</p>

<p align="center">
  <a href="#安装">安装</a> · <a href="https://kunkunred.hiwik.cn/projects/jot/docs/">使用文档</a> · <a href="docs/zh/guides/ai-agents.md">配合 AI agent</a> · <a href="docs/zh/reference/cli.md">CLI 参考</a> · <a href="README.md">English</a>
</p>

Jot 用来记工作中冒出来的需求、想法和待办，比如"搜索页太慢""v0.2 加 GPX 导出""续费证书"。你或你的 coding agent 一条命令就能记下来；Jot 会自动归到当前所在的 Git 仓库，之后在看板上从 Inbox 推到 In Progress 再到 Done。

它由三部分组成：带 JSON 输出的 `jot` CLI、原生 SwiftUI App、给 Claude Code / Codex 等 agent 用的 skill 文件。三者共用一份本地数据：元数据在 SQLite，每条需求的正文是一个 Markdown 文件。不需要账号、服务器或同步服务。

完整的中英文使用文档（带搜索）在 **[kunkunred.hiwik.cn/projects/jot/docs](https://kunkunred.hiwik.cn/projects/jot/docs/)**，仓库的 [`docs/zh/`](docs/zh/) 里也能直接读。

![Jot 看板](docs/images/board.png)

## 安装

**交给 agent 装**：把这句话发给 Claude Code、Codex 或其他 coding agent：

```text
Install the jot CLI and its skill by following https://github.com/RedHiwiK/jot/blob/main/docs/en/guides/ai-agents.md
```

**macOS App**（内置 CLI）：

```bash
curl -fsSLO https://github.com/RedHiwiK/jot/releases/latest/download/Jot_macos.zip
ditto -x -k Jot_macos.zip /Applications
xattr -dr com.apple.quarantine /Applications/Jot.app      # 只做了 ad-hoc 签名，未公证
mkdir -p ~/.local/bin && ln -sf /Applications/Jot.app/Contents/Helpers/jot ~/.local/bin/jot
```

**只装 CLI**（macOS 或 Linux）：

```bash
go install github.com/RedHiwiK/jot/cmd/jot@latest
```

也可以从 [Releases](https://github.com/RedHiwiK/jot/releases/latest) 下载 `jot_<os>_<arch>.tar.gz`。macOS 自带一个无关的 `/usr/bin/jot`，需要把 `~/.local/bin`（或 Go 的 bin 目录）放在 `PATH` 里 `/usr/bin` 之前，并确认 `jot --version` 输出 `jot version 0.1.0`。

## 快速上手

```bash
jot init                                             # 创建 ~/.jot
cd ~/code/myapp                                      # 任意 Git 仓库
jot add "搜索页太慢" --note "onChange 里直接查库" --tag v0.2
jot add "续费开发者证书" --unfiled                    # 个人事项，不归项目
jot ls                                               # 按状态列出进行中的需求
jot mv 1 in_progress
jot mv 1 done
jot ls --tag v0.2 --all --json                       # 某个版本的全部需求，JSON 输出
```

在仓库里第一次记录时会自动把它注册为项目。项目是可选的；`v0.2`、`bug` 这类标签可以跨项目使用。

## 在 AI agent 里使用

安装 skill（以 Claude Code 为例，Codex 放 `~/.codex/skills`）：

```bash
mkdir -p ~/.claude/skills/jot
curl -fsSL https://raw.githubusercontent.com/RedHiwiK/jot/main/skills/jot/SKILL.md -o ~/.claude/skills/jot/SKILL.md
```

之后正常说话就行：

- "记一下：小窗口下导出按钮被挡住了" → `jot add ...`，记完 agent 回到原来的任务。
- "myapp 还有哪些没做？" → `jot ls --project myapp --json` 并总结。
- "整理一下 inbox，发版要做的打上 v0.2" → `jot triage`、`jot tag`。
- "42 做完了" → `jot mv 42 done`。
- 为 42 号需求开了 PR 后，agent 会执行 `jot link 42 <url>`，并在 PR 里写 `JOT-42`。

skill 只管理需求，不会自己开始实现。详见 [AI agent](docs/zh/guides/ai-agents.md)。

## 从源码构建

需要 Go 1.27+、Swift 6、macOS 14+（只构建 CLI 的话有 Go 就行）。

```bash
make test          # go vet、go test、swift test
make install       # CLI 安装到 ~/.local/bin/jot
make install-app   # 构建 Jot.app 并复制到 /Applications
make dist          # 在 dist/ 生成发布包
```

欢迎贡献，见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

MIT，见 [LICENSE](LICENSE)。
