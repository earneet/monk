# Progress Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** SaveSystem autoload 持久化通关进度到 `user://progress.json`,启动水合、通关即存、坏档安全退化。

**Architecture:** `scripts/level/save_system.gd`(autoload,唯一)+ `LevelProgression.completed_ids()` 访问器 + `boot.gd` 两处接线。UI 零改动。

**上游 spec:** `docs/superpowers/specs/2026-10-16-progress-persistence-design.md`

**环境:** 同前(`$GODOT`;GUT 命令行 `--headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`)。

---

## 文件结构

| 文件 | 责任 | 新 |
|---|---|---|
| `scripts/level/save_system.gd` | SaveSystem autoload:load_completed / save_completed(JSON v1 + 容错) | 新 |
| `scripts/level/level_progression.gd` | 增 `completed_ids() -> Array[String]` | 改 |
| `scripts/ui/boot.gd` | `_ready` 水合 + `_on_level_won` 落盘 | 改 |
| `project.godot` | `[autoload]` 注册 SaveSystem | 改 |
| `tests/level/test_save_system.gd` | SaveSystem 单测(临时路径) | 新 |
| `tests/level/test_level_progression.gd` | 增 completed_ids 用例 | 改 |
| `tests/ui/test_boot.gd` | 增水合/落盘集成用例(路径重定向隔离) | 改 |

## 任务

### Task pp-1: LevelProgression.completed_ids()(TDD)
- [ ] 红:`test_completed_ids_returns_marked`(空 → [];标记 1-1 → ["1-1"])
- [ ] 绿:`_init` 后返回 `_completed` 键集合(Array[String])
- [ ] 提交

### Task pp-2: SaveSystem 模块(TDD)
- [ ] 红:`test_save_system.gd`——缺文件→[];往返;损坏 JSON→[];version≠1→[];空列表往返(实例 `save_path` 指临时文件,teardown 删)
- [ ] 绿:`save_system.gd` 实现(JSON.stringify / JSON.parse_string + 类型校验 + push_warning)
- [ ] 提交

### Task pp-3: autoload 注册 + boot 接线(TDD)
- [ ] 红:`test_boot.gd`——预置临时存档 → `boot._progression.is_completed("1-1")`;模拟 `_on_level_won` → 临时存档含 id
- [ ] 绿:project.godot 加 `[autoload]`;boot `_ready` 水合、`_on_level_won` 落盘
- [ ] 测试隔离:before_each 重定向 autoload `save_path` → 临时路径,after_each 清理恢复
- [ ] 提交(含上次 QA 遗留的 menu_designer 插件启用 hunk)

### Task pp-4: 全量 + QA
- [ ] 全量 GUT(151 + 新增)全绿
- [ ] 手动 QA:通关一关 → 重启进度保留;改坏存档 → 空进度不崩

## Self-Review
- D1~D5 全覆盖;容错四分支有测(pp-2);测试不触真实存档(pp-2 实例注入 / pp-3 重定向);UI 零改动(spec §3)。
