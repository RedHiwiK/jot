---
title: 文件与数据
description: Jot 把什么存在哪里、Markdown 格式和 SQLite 表。
group: reference
order: 3
---

所有数据都在同一个目录里：默认是 `~/.jot`，设置了 `JOT_HOME` 时则是 `$JOT_HOME`：

```
~/.jot/
├── jot.db                       SQLite (WAL)：元数据、状态历史、标签、链接、设置
├── themes/                      可选的自定义 App 主题 (*.json)
└── reqs/
    ├── _inbox/                  无项目的需求
    │   └── 0007-2026-10-20-Plan-the-weekend.md
    └── myapp/
        └── 0042-2026-10-18-Search-page-is-slow.md
```

备份时备份整个目录即可。除此之外 Jot 不会读写目录以外的任何内容，唯一的例外是读取已注册项目的 `.git/config`，用来推断其 Web 地址。

## Markdown 正文

正文以 Markdown 文件为准。frontmatter 是 SQLite 元数据的可读副本，CLI 每次变更时都会重写：

```markdown
---
id: 42
title: "Search page is slow"
state: in_progress
project: "myapp"
tags: [v0.2, perf]
created: 2026-10-18T09:12:44+08:00
---

## Requirement

Search page is slow

## Acceptance criteria

- [ ] 

## Notes

Traced to a direct DB query inside onChange
```

这三个标题和 frontmatter 的键一样，属于固定的文件格式。标题下的内容按输入原样保存，任何语言都可以。可以用 `jot edit`、`jot body set` 或 App 编辑正文；直接编辑文件也可以，但元数据只能通过 CLI 修改，因为 `jot sync` 会按 SQLite 中的数据重写 frontmatter。

## SQLite 表

| 表 | 内容 |
|---|---|
| `reqs` | 编号、标题、正文路径、状态、可选的项目、优先级、录入目录和备注、创建/更新/开始/完成时间戳 |
| `projects` | 名称、路径、可选的颜色和仓库地址 |
| `state_log` | 每次状态流转：起始状态、目标状态、操作者、时间 |
| `req_tags` | `(req_id, tag)` 对；标签列表来自 `SELECT DISTINCT`，所以不再使用的标签会自动消失 |
| `req_links` | 按绑定顺序保存的 `(req_id, url)` 对 |
| `meta` | 编辑器等设置 |

表结构见 [`internal/store/schema.sql`](https://github.com/RedHiwiK/jot/blob/main/internal/store/schema.sql)。App 从不直接打开数据库：它调用内置的 CLI 并解析其 JSON，因此状态规则、项目推断和 frontmatter 同步都只存在于一处。

## 一致性

正文的写入是原子的（先写临时文件，再重命名）。SQLite 和文件无法共享事务：如果元数据已变更而文件操作随后失败，命令会报告这一情况，可以用 `jot sync` 修复 frontmatter。删除项目时如果移动正文失败，会整体回滚。
