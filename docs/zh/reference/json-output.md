---
title: JSON 输出
description: --json 返回的机器可读结构。
group: reference
order: 2
---

所有数据命令都支持 `--json`。下面的结构是与 macOS App 和 agent 之间的契约：字段只会增加，不会改名或删除。空字段会被省略，因此所有可选字段都要按"可能不存在"处理。

## 需求

由 `add`、`show`、`set`、`mv`、`tag`/`untag`（在 `reqs` 内）以及 `ls`（在 `reqs` 内）返回。

```json
{
  "id": 1,
  "title": "Search page is slow",
  "priority": 0,
  "state": "inbox",
  "project": "myapp",
  "tags": ["v1.2"],
  "links": ["https://github.com/owner/myapp/pull/12"],
  "path": "myapp/0001-2026-10-20-Search-page-is-slow.md",
  "note": "Traced to a DB query inside onChange",
  "origin_cwd": "/home/me/code/myapp",
  "created_at": "2026-10-20T16:55:34+08:00",
  "updated_at": "2026-10-20T16:55:34+08:00"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | integer | 稳定不变，不会被复用 |
| `title` | string | |
| `priority` | integer | `0` 普通，`1` 高 |
| `state` | string | `inbox`、`in_progress`、`on_hold`、`done`、`archived` |
| `project` | string | 无项目时省略 |
| `tags` | string[] | 已规范化并排序；为空时省略 |
| `links` | string[] | 按绑定顺序；为空时省略 |
| `path` | string | 相对于 `~/.jot/reqs/` 的正文文件路径；`jot path <id>` 会输出绝对路径 |
| `note` | string | 在 `ls` 中是录入备注；在 `show` 中是不含 frontmatter 的完整正文 |
| `origin_cwd` | string | 录入该需求时所在的目录 |
| `created_at`, `updated_at` | string | 带时区偏移的 RFC 3339 格式 |

## `ls`

```json
{
  "reqs": [ /* requirement objects */ ],
  "projects": [ /* project objects */ ],
  "tags": [ { "tag": "v1.2", "count": 1 } ],
  "detected_project": "myapp",
  "cwd": "/home/me/code/myapp"
}
```

`projects` 和 `tags` 始终描述整个数据目录，而不只是筛选后的结果，所以一次调用就能知道现有的全部内容。`detected_project` 是当前目录对应的项目（如果有的话）。

## 项目

由 `project ls`（返回数组）以及 `ls` 内部返回。

```json
{
  "name": "myapp",
  "repo_path": "/home/me/code/myapp",
  "open_count": 1,
  "color": "blue",
  "repo_url": "https://github.com/owner/myapp",
  "repo_url_inferred": true
}
```

`open_count` 统计未完成且未归档的需求数量。当 URL 来自 `origin` remote 而非 `project set --repo-url` 时，`repo_url_inferred` 为 `true`。

## `tag ls`

```json
{ "tags": [ { "tag": "bug", "count": 2 }, { "tag": "v1.2", "count": 4 } ] }
```

## 批量结果

`triage`、`tag` 和 `untag` 会处理每一项，并返回：

```json
{
  "reqs": [ /* requirements that succeeded */ ],
  "failed": [ "#99: requirement not found" ]
}
```

如果 `failed` 不为空，命令还会向 stderr 输出 `error: N requirement(s) failed`，并以状态码 1 退出。两者都要检查。

`add` 是例外：单个标题时返回一个需求对象，多个标题（来自 `--stdin`、管道或多行参数）时返回数组。它遇到第一个错误就会停止，此前的标题已经录入。

## 错误

错误以 `error: <message>` 的形式写到 stderr，退出状态码为 1；stdout 为空，或包含部分批量结果。常见消息：

| 消息 | 含义 |
|---|---|
| `not initialized yet; run: jot init` | 数据目录不存在 |
| `requirement not found` | 没有该编号的需求 |
| `project "x" is not registered` | 先用 `jot project add` 注册 |
| `unknown state "x"` | 请使用五种状态之一 |
