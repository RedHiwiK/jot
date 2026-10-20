---
title: 项目与标签
description: 用可选的项目、自由格式的标签和归类来整理需求。
group: guides
order: 2
---

项目回答"这属于哪里？"，标签回答"这是关于什么的？"。一条需求最多属于一个项目，可以有任意数量的标签。

## 项目

项目是带有路径的命名分类，通常对应一个 Git 仓库。你很少需要手动创建：在仓库内的首次录入会自动注册项目，名称取自仓库目录名。如果名称已被占用，则追加上级目录名（如 `api-work`、`api-personal`）。

```bash
jot project ls
jot project add notes ~/Documents/notes      # 任意文件夹都可以，是否为 Git 仓库均可
jot project rename myapp my-app
jot project rm my-app
```

`project rm` 只删除分类。其中所有需求（包括已完成和已归档的）都会变为无项目，状态和正文保持不变，不会删除任何仓库或文件。之后在该仓库内再次录入会重新注册项目；用 `jot add --unfiled` 可以避免。

### 移动需求

```bash
jot set 42 --project myapp
jot set 42 --project ""          # 变为无项目
```

Markdown 文件会移到 `~/.jot/reqs/` 下新项目对应的目录。

### 显示设置

```bash
jot project set myapp --color blue                            # red, orange, yellow, green, teal, blue, purple, gray; "" 表示清除
jot project set myapp --repo-url https://github.com/o/myapp   # "" 表示回退到 Git remote
```

颜色只用于给 App 侧栏中项目的文件夹图标着色；卡片始终使用状态颜色。未设置时，仓库地址会从 `origin` remote 推断。

App 的**设置 → 项目**页也可以调整项目顺序、重命名、删除项目，以及设置仓库地址。

## 归类

归类（triage）用来为在仓库之外录入的需求补上缺失的项目：

```bash
jot triage 42 43 44
jot triage 42 43 --project myapp
```

不带 `--project` 时，已有项目会保留；否则 Jot 先尝试录入该需求时所在的目录，再尝试当前目录。归类从不改变状态。结果按需求逐条返回；失败的会列出，并使命令以非零退出码退出。

## 标签

标签是自由格式的标记：发布版本（`v1.2`）、主题（`bug`、`perf`），什么都可以。

```bash
jot tag 42 v1.2                 # 添加，保留已有标签
jot tag 42 43 44 v1.2           # 一次处理多条需求
jot untag 42 v1.2
jot tag 42 --clear
jot set 42 --tags v1.2,bug      # 替换全部标签
```

规则：

- 标签会转为小写，并去掉开头的 `#`：`#V1.2` 和 `v1.2` 是同一个标签。
- 保留字母、数字和 `. _ / -`；空格和逗号用来分隔标签。
- 开头的纯数字参数会被当作需求编号，所以纯数字标签要通过 `--tag` 传入：`jot tag 42 --tag 2026`。
- 没有标签注册表。只要还有至少一条需求带着某个标签，这个标签就存在。

### 管理标签

```bash
jot tag ls                      # 列出所有在用的标签及数量
jot tag rename v1.2 v1.2.1
jot tag rm v1.2                 # 在所有地方移除该标签；需求保留
```

## 筛选

```bash
jot ls --project myapp
jot ls --tag v1.2 --tag bug         # 同时带有两个标签（AND）
jot ls --tag-any v1.2,v1.3          # 带有任一标签（OR）
jot ls --untagged
jot ls --tag v1.2 --all             # 包含已完成和已归档
```

在 App 中，点击需求上的标签，可以查看带有该标签的活跃需求。
