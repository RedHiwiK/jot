---
title: macOS App
description: 在原生看板上浏览和维护需求。
group: guides
order: 4
---

Jot.app 是基于 SwiftUI 的原生看板，要求 macOS 14 及以上。它用于浏览和维护需求；录入通过 CLI 或 agent 完成，所以 App 里没有"新建需求"的表单。

App 只通过内置的 CLI（`Jot.app/Contents/Helpers/jot`）读写数据。因此 App、CLI 和 skill 看到的始终是同一份数据，遵循同一套规则。

## 界面布局

- **侧栏**：显示全部活跃需求、各状态（收件箱、进行中、暂缓、已完成）及其数量，以及你的项目。项目的文件夹图标使用该项目的颜色。
- **看板**：每个活跃状态一列。把卡片拖到另一列即可修改状态。
- **详情**：Markdown 正文、标题、标签和关联的 pull request。双击标题可重命名；点击**编辑**修改正文，然后**保存**或**取消**。
- **侧边面板**：需求编号（点击即可复制）、项目、录入目录和日期。用 <kbd>⌥⌘I</kbd> 显示或隐藏。

点击需求上的标签，可以查看带有该标签的活跃需求。

## 搜索

<kbd>⌘F</kbd> 打开搜索，范围包括编号、标题、项目、状态和录入备注，涵盖活跃和历史需求。用方向键选择，<kbd>Return</kbd> 打开，<kbd>Esc</kbd> 关闭。

## 键盘快捷键

| 快捷键 | 操作 |
|---|---|
| <kbd>⌘1</kbd> … <kbd>⌘5</kbd> | 看板、收件箱、进行中、暂缓、已完成 |
| <kbd>⌥1</kbd> … <kbd>⌥9</kbd> | 按侧栏顺序切换项目（按住 <kbd>⌥</kbd> 可查看序号） |
| <kbd>⌘F</kbd> | 搜索 |
| <kbd>⌘R</kbd> | 刷新 |
| <kbd>⌥⌘I</kbd> | 显示或隐藏侧边面板 |
| <kbd>⌘[</kbd> | 返回 |

所有快捷键都可以在**设置 → 键盘快捷键**中修改。

## 设置

用 <kbd>⌘,</kbd> 或侧栏底部的齿轮图标打开设置。

| 分页 | 可以做什么 |
|---|---|
| 通用 | 在 English 和简体中文之间切换语言 |
| 外观 | 选择主题：Newsprint、Paper、Solarized Light、One Dark，或自定义主题 |
| 项目 | 调整侧栏中项目的顺序（同时决定 <kbd>⌥1</kbd>…<kbd>⌥9</kbd> 对应的项目），重命名或删除项目，设置仓库地址 |
| 键盘快捷键 | 为任意操作录入新的快捷键 |
| 已归档 | 浏览已归档的需求，并将其恢复到收件箱 |

项目颜色通过 `jot project set <name> --color <color>` 设置；App 会显示颜色，但没有对应的编辑入口。

### 自定义主题

在外观页点击**导出模板**，会把一个示例主题写入 `~/.jot/themes/`。复制它，修改名称和颜色，然后点击**重新扫描**。该目录下每个 `*.json` 文件都会成为一个主题；未写出的颜色沿用 Paper 主题。

## 保持同步

通过 CLI 或 agent 所做的改动会在 15 秒内出现，按 <kbd>⌘R</kbd> 可立即刷新。在 App 里做的编辑会先经由 CLI 写入，再更新视图；如果写入失败，错误提示会一直保留，你输入的文字也不会丢失。

## 用临时数据试用

App 会把环境变量传给 CLI，所以 `JOT_HOME` 同样有效：

```bash
JOT_HOME=/tmp/jot-demo jot init
JOT_HOME=/tmp/jot-demo /Applications/Jot.app/Contents/MacOS/Jot
```

如果找不到内置的 CLI（例如通过 `swift run` 运行时），App 会依次查找 `~/.local/bin/jot`、`/usr/local/bin/jot` 和 `/opt/homebrew/bin/jot`。
