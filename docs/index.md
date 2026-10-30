---
title: Overview
permalink: /
description: "remindctl is a fast macOS CLI for Apple Reminders, built for terminals, scripts, and agents."
---

## Try it

```bash
brew install steipete/tap/remindctl

remindctl add "Buy milk"
remindctl add "Call mom" --list Personal --due tomorrow
remindctl add "Meeting" --due "2026-01-03 09:00" --alarm "2026-01-03 08:55"

remindctl today
remindctl overdue
remindctl open
remindctl list Work Errands
remindctl list --list-id 7A12
remindctl search "milk"
remindctl info 1
remindctl doctor --for-agent
remindctl export --list Work --export-format csv
remindctl link 1

remindctl edit 1 --title "New title" --due 2026-01-04
remindctl complete 1 2 3
remindctl delete 4A83 --force
```

Indexes such as `1` come from the default reminder listing. Most commands also accept an ID prefix such as `4A83`.

## What remindctl does

- Uses Apple's public EventKit APIs, so changes sync through the normal Reminders and iCloud path.
- Reads and updates reminders from scripts, terminals, CI helpers, and local agents.
- Supports due dates, alarms, recurrence, priorities, notes, exact list IDs, completion, deletion, and location triggers.
- Emits JSON for automation, TSV with `--plain`, tables with `--format table`, and compact human output by default.
- Includes `doctor`, `export`, `link`, `open`, and shell completion helpers for agent workflows.
- 支持原生 flag/tag 编辑和 `info --native` 查询, 通过系统私有 ReminderKit 接口保存, 不直接写数据库.  sections, smart lists, attachments 和 "Urgent" 仍不支持.  

## Pick your path

- Install from Homebrew or source in [Install](install.md).
- See day-to-day syntax in [Commands](commands.md).
- Check macOS permission setup in [Permissions](permissions.md).
- Run local UI checks with [Manual Tests](manual-tests.md).
- Release notes and shipped changes live in the [changelog](https://github.com/openclaw/remindctl/blob/main/CHANGELOG.md).

Released under the [MIT license](https://github.com/openclaw/remindctl/blob/main/LICENSE). Not affiliated with Apple.
