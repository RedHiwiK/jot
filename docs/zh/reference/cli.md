---
title: CLI 参考
description: 所有 jot 命令和参数。
group: reference
order: 1
---

所有写入操作都以 `jot` 为唯一数据源：macOS App 和 agent skill 都调用它。每个读写数据的命令都支持 `--json`，输出机器可读的结果（参见 [JSON 输出](./json-output.md)）；不加时，输出是简短的人类可读回执。

任何命令都可以用 `jot <command> --help` 查看完整的参数列表。

## 初始化与设置

```bash
jot init                      # 创建 ~/.jot（或 $JOT_HOME）
jot config set editor nano    # `jot edit` 使用的编辑器；回退到 $EDITOR，再回退到 vi
jot config ls --json
```

## 录入

```bash
jot add "Title"
jot add "Title" --note "Context, conclusion or acceptance criteria"
jot add "Title" --project myapp
jot add "Personal task" --unfiled
jot add "Title" --tag v0.2 --tag bug
jot add --stdin < titles.txt          # 每行一条需求
```

新需求的初始状态是 `inbox`。不带 `--project` 时，项目由当前目录推断：在 Git 仓库内，该仓库会自动注册为项目（以目录名命名）；在其他位置，需求没有项目。`--unfiled` 会跳过推断。

单个标题的 `add --json` 返回一个需求对象；多个标题（来自 `--stdin`、管道或多行参数）返回数组。`add` 遇到第一个错误就会停止，此前已录入的标题保留。

## 查询

```bash
jot ls                               # 按状态分组列出活跃需求
jot ls --all                         # 包含已完成和已归档
jot ls --state on_hold
jot ls --project myapp
jot ls --tag v0.2 --tag bug          # 同时带有所有这些标签（AND）
jot ls --tag-any v0.2,v0.3           # 带有其中任一标签（OR）
jot ls --untagged
jot show 42 --json                   # 元数据，完整正文放在 `note` 中
jot body 42                          # 不含 frontmatter 的正文
jot path 42                          # Markdown 文件的绝对路径
```

`ls --json` 返回 `{reqs, projects, tags, detected_project, cwd}`：每次列表都附带完整的项目和标签列表，所以很少需要再单独调用 `project ls` 或 `tag ls`。在 `ls` 中，`note` 是录入备注；在 `show` 中，`note` 是完整正文。

## 编辑

```bash
jot set 42 --title "New title"
jot set 42 --priority 1              # 0 普通，1 高
jot set 42 --project myapp
jot set 42 --project ""              # 变为无项目
jot set 42 --tags v0.2,bug           # 替换全部标签
jot body set 42 < body.md            # 替换正文（不含 frontmatter 的 Markdown）
jot edit 42                          # 在已配置的编辑器中打开正文
jot triage 42 43 --json              # 补全缺失的项目
jot triage 42 43 --project myapp --json
```

修改项目会把 Markdown 文件移到新项目的目录。`triage` 会保留已有的项目，否则先尝试录入该需求时所在的目录，再尝试当前目录，并且从不改变状态。显式指定 `--project` 时以它为准。

## 工作流

```bash
jot mv 42 in_progress
jot mv 42 on_hold
jot mv 42 done
jot mv 42 inbox
jot rm 42                            # 归档（可恢复）
jot mv 42 inbox                      # 恢复已归档的需求
jot purge 42 --yes                   # 永久删除已归档的需求
```

| 状态 | 含义 |
|---|---|
| `inbox`（收件箱） | 已录入，尚未开始 |
| `in_progress`（进行中） | 正在处理，包括评审和验收 |
| `on_hold`（暂缓） | 推迟，或在等待外部条件 |
| `done`（已完成） | 已完成 |
| `archived`（已归档） | 不会做了；仍可搜索和恢复 |

状态由人手动设置（或由用户委托的 agent 设置）：它记录的是意图，而不是某个进程是否在运行。每次流转都会记录在 `state_log` 中。

`purge` 只接受已归档的需求，除非加上 `--yes`，否则会要求确认。它会删除数据库记录和 Markdown 文件。

## 标签

```bash
jot tag 42 v0.2                      # 添加，保留已有标签
jot tag 42 43 44 v0.2                # 一次处理多条需求
jot tag 42 --tag 2026                # 字面值（纯数字标签必须这样写）
jot untag 42 v0.2
jot tag 42 --clear
jot tag ls --json                    # 列出所有在用的标签及数量
jot tag rename v0.2 v0.3
jot tag rm v0.2                      # 在所有地方移除该标签；需求保留
```

标签是与项目正交的自由格式标记：一条需求最多属于一个项目，但可以有任意数量的标签。标签会规范化为小写并去掉开头的 `#`，所以 `#V0.2` 和 `v0.2` 是同一个标签。保留字母、数字和 `. _ / -`；空格和逗号用来分隔标签。

在 `tag` 和 `untag` 中，开头的纯数字参数会被当作需求编号，所以纯数字标签要通过 `--tag` 传入，且不能与位置参数形式的标签混用。没有标签注册表：只要还有需求带着某个标签，这个标签就存在。

## 链接

```bash
jot link 42 https://github.com/owner/repo/pull/12
jot unlink 42 https://github.com/owner/repo/pull/12
jot unlink 42 --all
```

链接把 pull/merge request 的 URL 绑定到需求上。它们会作为 `links` 出现在需求 JSON、frontmatter 以及 App 的详情页中。Jot 不会从托管平台拉取任何内容。在 PR 标题、描述和 commit 中请把需求写成 `JOT-42`；单独的 `#42` 会与托管平台自己的编号冲突。

## 项目

```bash
jot project add myapp ~/code/myapp
jot project ls --json
jot project rename myapp my-app
jot project set myapp --color blue                         # red/orange/yellow/green/teal/blue/purple/gray；"" 表示清除
jot project set myapp --repo-url https://github.com/o/r    # "" 表示回退到 Git remote
jot project rm myapp --json
```

项目是可选的分类，不一定是 Git 仓库。`project ls --json` 中的 `repo_url` 要么是手动配置的，要么是从 `origin` remote 推断的（`repo_url_inferred: true`）。颜色只用于给 App 侧栏中项目的文件夹图标着色。

`project rm` 只删除分类：其中所有需求（包括已完成和已归档的）都会变为无项目，状态和正文保持不变，不会删除任何仓库或需求文件。之后在该仓库内再次录入会重新注册项目；用 `add --unfiled` 可以避免。

## 批量结果与错误

批量命令（`triage`、`tag`、`untag`）会处理每一项，并在 JSON 中返回 `{reqs, failed}`。只要有任何失败，命令就以非零退出码退出，所以要同时检查退出码和 `failed`。

错误以 `error: ...` 的形式写到 stderr，退出码为 1。`not initialized yet; run: jot init` 表示数据目录不存在。

## 维护

```bash
jot sync     # 按 SQLite 中的数据重写所有 frontmatter
```

SQLite 和 Markdown 文件无法共享事务。如果某个命令提示元数据已更新但正文同步失败，请运行 `jot sync`。
