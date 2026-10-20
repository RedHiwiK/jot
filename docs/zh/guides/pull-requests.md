---
title: Pull request
description: 把 pull request 和 merge request 绑定到需求上。
group: guides
order: 6
---

当需求落到代码上时，把对应的 pull request 或 merge request 绑定到它。链接会出现在 JSON、Markdown frontmatter 以及 App 中该需求的详情页里。

```bash
jot link 42 https://github.com/owner/repo/pull/12
jot link 42 https://gitlab.example.com/group/repo/-/merge_requests/7
jot unlink 42 https://github.com/owner/repo/pull/12
jot unlink 42 --all
```

`link` 是增量的：绑定第二个 PR 时会保留第一个。链接按绑定顺序列出。Jot 只存储 URL，从不访问托管平台。

## 引用需求

在 PR 标题、描述和 commit message 中写 `JOT-42`。单独写 `#42` 会被 GitHub 和 GitLab 转成指向 issue 或 PR 42 的链接。

```text
fix(search): query the index instead of the table (JOT-42)
```

## 配合 agent

skill 会要求 agent 在为某条需求提交 PR 之后立即执行 `jot link <id> <url>`，并在 PR 文本中使用 `JOT-<id>` 的写法。
