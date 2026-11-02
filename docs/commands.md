---
title: Commands
description: "Common remindctl commands and options."
---

# Commands

## Show reminders

```bash
remindctl today
remindctl tomorrow
remindctl week
remindctl overdue
remindctl upcoming
remindctl open
remindctl completed
remindctl all
remindctl 2026-01-03
```

`week` and `show week` include incomplete reminders due within the current calendar week, including its start but excluding the opening midnight of the next week.

Limit a view to one list:

```bash
remindctl show overdue --list Work
remindctl show overdue --list-id 7A12
```

Show multiple lists together:

```bash
remindctl list Work Errands
```

## Create reminders

```bash
remindctl add "Review notes"
remindctl add "Call Sam" --list Work --due tomorrow
remindctl add "Call Sam" --list-id 7A12 --due tomorrow
remindctl add "Take vitamins" --due tomorrow --repeat daily
remindctl add "Check mailbox" --location "1 Apple Park Way, Cupertino, CA"
```

Useful `add` options:

- `--list <name>` chooses the target list.
- `--list-id <id-prefix>` chooses the target list exactly.
- `--due <date>` sets a due date.
- `--alarm <date>` sets a notification alarm.
- `--notes <text>` adds notes.
- `--repeat <rule>` sets simple recurrence.
- `--priority <none|low|medium|high>` sets priority.
- `--url <url>` stores the EventKit URL and mirrors it into notes as `remindctl URL (managed): ...` so Reminders.app shows the link.
- `--location <address>` creates an arriving geofence trigger.
- `--leaving` changes a location trigger to leaving.
- `--radius <meters>` adjusts the geofence radius.

Due dates and alarms accept relative dates, `YYYY-MM-DD`, local date-times, and ISO 8601 timestamps with explicit offsets. Impossible dates, invalid offsets, and trailing text fail instead of being normalized to another date. Unpadded month/day/time fields, extra spaces before a time, and year-first `/` or `.` separators remain accepted. Legacy slash dates use `MM/dd/yyyy`; day-first hyphen dates use `dd-MM-yy` or `dd-MM-yyyy`.

`--alarm` schedules a notification; it does not enable the native **Urgent** toggle in Reminders.app. EventKit does not expose Urgent, so `remindctl` cannot set it. Use `--alarm` for a notification, or enable Urgent directly in Reminders.app.

## Edit reminders

```bash
remindctl edit 1 --title "New title"
remindctl edit 4A83 --due "2026-01-04 09:00"
remindctl edit 4A83 --clear-due
remindctl edit 4A83 --list Office
remindctl edit 4A83 --list-id 7A12
remindctl edit 4A83 --no-repeat
remindctl edit 4A83 --flag
remindctl edit 4A83 --unflag
remindctl edit 4A83 --add-tag work --add-tag "#项目"
remindctl edit 4A83 --remove-tag work
remindctl edit 4A83 --rename-tag 项目 --to-tag 已归档
remindctl info 4A83 --native --json
```

`--flag` 和 `--unflag` 分别添加和删除 Reminders.app 原生旗标.  `--add-tag` 和 `--remove-tag` 可以重复使用, 标签名可以带一个 `#` 前缀, 但不能包含空格或额外的 `#`.  重复添加已有标签或删除不存在的标签不会产生额外变更.  标签匹配不区分大小写.  

`--rename-tag <旧名称> --to-tag <新名称>` 只修改指定提醒上的标签, 不会重命名其他提醒上的同名标签.  原标签不存在时会报错, 新标签已存在时会合并.  flag 和 tag 操作可以合并在同一条命令中, 所有变更在同一次原生事务中保存.  冲突参数或无效标签会在保存前报错.  

flag/tag 使用系统私有 ReminderKit 接口, 不直接修改 Reminders 数据库.  它们需要与标题, 日期, 备注等 EventKit 字段分开执行, 混用时命令会拒绝保存.  macOS 更新可能改变私有接口, 接口缺失或系统拒绝访问时会返回具体错误.  普通命令继续使用 EventKit.  

`info --native` 和 flag/tag 编辑结果的 JSON 包含 `isFlagged` 与 `tags`, 可以核对保存后的原生状态.  不带 `--native` 的普通读取不会查询这些字段, 字段缺失表示未读取, 不能当作没有 flag 或 tag.  

Moving a reminder with `--list` or `--list-id` can fail when the source or destination list is shared. If EventKit rejects the move with `com.apple.reminderkit error -3002`, move the reminder in Reminders.app, then retry any other edits. The command does not fall back to copying and deleting the reminder, since public EventKit cannot preserve all Reminders.app metadata.

Commands that target reminders accept indexes from the current default listing or ID prefixes.
An in-range numeric value always selects that index. An out-of-range numeric value falls back to ID-prefix matching and returns an error when no reminder ID matches.
`complete` and `delete` process each reminder once, even when repeated indexes, IDs, or prefixes identify the same reminder. Previews and delete confirmation counts use these unique targets in first-input order; every input must still be valid and unambiguous.
Reminders sort by due date, then title, then stable ID so equal dates and titles do not make numeric targets depend on EventKit's fetch order. Use IDs when reminders may be added, removed, or edited between commands.

If `add`, `edit`, or `complete` reports `Reminder is missing a calendar`, EventKit saved the reminder but returned it without its list. Check Reminders.app before retrying; this error does not roll back the saved change.

Changing or clearing only the due date leaves every alarm unchanged. Explicit alarm edits preserve relative and location-based alarms while replacing or clearing absolute alarms.
As with `add`, `edit --alarm` schedules a notification without enabling native Urgent. Set Urgent in Reminders.app.

## Lists

```bash
remindctl list
remindctl list Work
remindctl list Projects --create
remindctl list Work --rename Office
remindctl list OldList --delete --force
remindctl list --list-id 7A12
remindctl list --list-id 7A12 --rename Archive
```

Mutating list operations accept one list name. Read-only list views can accept multiple names.
`list <name> --delete --force --json` 和 `list --list-id <id> --delete --force --json` 删除成功后返回 `{"deleted":1}`, 可以直接解析 JSON 结果.  
Choose only one of `--create`, `--delete`, or `--rename`, and provide its target; conflicting or missing mutation targets fail before accessing Reminders.
`list <name> --create` creates a missing list or reuses a unique matching list. Repeating it preserves the list and its reminders; `--json` reports the current incomplete and overdue counts. An ambiguous name fails instead of creating another list.
List names resolve by exact match, case-insensitive match, then a normalized match that ignores emoji and punctuation.
If a name is ambiguous, use `--list-id`.

## Search and inspect

```bash
remindctl attachments 4A83 --json
remindctl attachments 4A83 --output ./attachments --json
remindctl search "invoice" --list Work
remindctl search "project" --completed --json
remindctl info 1
remindctl info 4A83 --json
```

`attachments <id>` 读取指定提醒的原生图片和文件附件, 不修改提醒.  `--json` 返回附件数组, 没有附件时返回 `[]`.  每个附件包含 `id`, `reminderID`, `kind`, `contentType`, `byteCount`, `filename` 和 `isAvailable`.  网页链接不算图片或文件附件.  

普通 `show`, `list <name>`, `info`, `search` 和 JSON 导出默认包含 `attachmentCount`, 不需要加 `--native`.  数量大于 0 时, 可以继续执行 `remindctl attachments <id>` 查看或导出.  数量包含尚未下载的图片和文件附件, 不包含网页链接.  普通文本列表显示 `attachments=N`, `info` 会提供下一步命令.  plain 和 table 在末尾追加附件数量列, CSV 在末尾追加 `attachmentCount` 和 `attachmentError`.  

附件计数读取失败或超时时仍返回提醒内容, JSON 中省略 `attachmentCount` 并提供 `attachmentError`, 标准错误中也会记录具体原因, 文本数量显示 `unknown`.  缺失数量表示未知, 只有 `attachmentCount: 0` 才表示确认没有图片或文件附件.  

`--output <目录>` 将全部可用附件复制到本机目录, JSON 中的 `exportedPath` 是实际文件路径, 可直接交给图片查看或文件读取工具.  导出名使用附件 UUID 加文件类型扩展名, 因为系统接口不提供原始文件名.  命令拒绝覆盖已有文件, 也拒绝向 Reminders 数据目录导出.  没有附件时不创建目录.  

附件读取依赖系统私有 ReminderKit 接口.  目前只导出已经下载且可读取的本地附件; 未下载或不可访问时, 列举结果用 `isAvailable: false` 和 `unavailableReason` 说明原因, 导出命令报错.  可先在 Reminders.app 下载附件后重试.  复制中途发生文件系统错误时会说明原因, 已复制的文件保留在输出目录.  

## Export, links, and app handoff

```bash
remindctl export --json
remindctl export --list Work --export-format csv
remindctl link 1
remindctl link --list-id 7A12
remindctl open 1
remindctl open --list Work
remindctl open --list Work --app
remindctl completion zsh
```

`open --list Work` keeps the historical open-reminders filter. Add `--app` to open that list in Reminders.app.

CSV export quotes multiline fields, including Windows-style CRLF text, and neutralizes formula prefixes after leading whitespace or newlines. Managed URL-note replacement and `--clear-url` also recognize CRLF lines while preserving authored text and its newline style.

## Diagnostics

```bash
remindctl status
remindctl doctor --for-agent
```

## Output

```bash
remindctl all --json
remindctl list --json
remindctl today --plain
remindctl today --format table
remindctl status --json
```

Global output flags:

- `--json` emits machine-readable JSON.
- `--plain` emits stable tab-separated lines.
- `--format table` emits tabular output.
- `--quiet` emits minimal output.
- `--no-color` disables colored output.
- `--no-input` disables interactive prompts.

Use `--` before positional text that starts with a hyphen, including literal help or version flags:

```bash
remindctl add -- "--help"
```

Help and version flags after `--` are passed to the command as text.
