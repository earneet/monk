# 实施设计:monk 关卡设计工具增量——obstacle 微调 UI

> **任务来源**: 「全做」4 子增量第 2 个(undo 已完成,merge=4d970c6,93 测试绿)。本 spec 是 obstacle 微调 UI 子批次。
> **任务内容**: 关卡工具加障碍微调——点击路径外格循环改障碍类型(默认填充→假山→流水→默认),记入 `obstacle_overrides`,`Filler` 自动反映。解决「智能填充不符设计意图时无法逐格改」的痛点。
> **参考文档**:
> - `docs/project/2026-07-09-level-design-tool-design.md` — §9 空白处理(`obstacle_overrides` + `fill_rule` 合成)
> - `docs/superpowers/specs/2026-07-12-level-design-tool-mvp-design.md` — MVP spec(`Filler._override_tile` 已支持 `obstacle_overrides`)
> - `scripts/tool/filler.gd` + `addons/level_designer/level_canvas.gd` — 现状接入点
> **生成日期**: 2026-07-12

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-12 |
| 状态 | 实施级 spec,待用户审 → writing-plans |
| 产物路径 | `docs/superpowers/specs/2026-07-12-level-tool-obstacle-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming(交互决策)→ 本文档 → writing-plans |
| 上游 | 设计级 spec §9、MVP spec、Filler/canvas 现状 |
| 下游 | writing-plans 逐步实施计划 |

## 1. 范围

**纳入**:
- `LevelCanvas.Mode` 加 `OBSTACLE`
- `_gui_input` `OBSTACLE` 模式:点击**路径外**格循环改障碍(默认→假山→流水→默认)
- `_cycle_obstacle`:更新 `work.obstacle_overrides` + `push_undo` 反向
- `_draw` 自动反映(`Filler.fill` 读 `obstacle_overrides`)
- MainView mode_option 加「障碍」项

**不纳入**:
- 选特定类型模式(用循环替代,更简)
- `obstacle_overrides` 的 inspector 编辑

## 2. 关键决策与理由(避免长期遗忘)

| # | 决策 | 理由 | 弃选替代及其原因 |
|---|---|---|---|
| D1 | 循环改 3 态(左键循环 默认→假山→流水→默认) | 单击切换最简,无需额外选类型控件 | 选类型模式(先选后点):多一步、加控件,复杂 |
| D2 | `Filler`/`Exporter` 不改 | MVP `Filler._override_tile` 已读 `obstacle_overrides`,本增量只填它,导出路径无需动 | 改 Filler:无必要,违反外科手术式 |
| D3 | obstacle 改动 `push_undo` | 与反向栈 undo 一致;微调试错需撤销 | 不记 undo:不一致、试错无退路 |

## 3. 实现

**LevelCanvas**:
- `enum Mode` 加 `OBSTACLE`
- `_gui_input`:`mode == OBSTACLE` 且 `coord not in work.path` → `_cycle_obstacle(coord)`
- `_cycle_obstacle(coord)`:按 `obstacle_overrides[coord]` 当前值循环(`""→"WALL"→"FLOWING_WATER"→erase`),每步前 `push_undo` 反向;`queue_redraw()`
- `_set_override(coord, value)`:helper(undo 反向用,`""` 则 erase)

**MainView**:mode_option add_item("障碍", LevelCanvas.Mode.OBSTACLE)

> `_draw` 已调 `Filler.fill(work)`,后者读 `obstacle_overrides` → 改动自动反映,无需改 `_draw`。

## 4. 任务切片(TDD,喂给 writing-plans)

| # | 模块 | 红测 → 绿 | 测试 |
|---|---|---|---|
| 1 | `test_filler.gd` 补 obstacle_overrides 测试 | override 覆盖默认填充(WALL↔FLOWING_WATER) | GUT(MVP 未测,补锁行为) |
| 2 | `level_canvas.gd` OBSTACLE 模式 + `_cycle_obstacle` | 手动:点路径外格循环改障碍 | 手动 |
| 3 | `main_view.gd` mode_option 加障碍 | 手动 | 手动 |

## 5. 验收

- [ ] 障碍模式点路径外格循环改障碍(默认/假山/流水)
- [ ] 导出 .tres 反映 obstacle_overrides
- [ ] obstacle 改动可 undo(反向栈)
