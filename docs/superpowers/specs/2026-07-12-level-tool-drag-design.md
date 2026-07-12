# 实施设计:monk 关卡设计工具增量——drag 拖拽画路径

> **任务来源**: 「全做」4 子增量第 3 个(undo/obstacle 已完成,obstacle merge=63182c4)。本 spec 是 drag 拖拽画路径子批次。
> **任务内容**: NONE 模式支持拖拽手画路径(按下起点 + 拖拽经过格连续追加 + 释放结束),提升画长路径效率。
> **参考文档**:
> - `docs/project/2026-07-09-level-design-tool-design.md` — §7 路径输入(拖拽手画 LD4)
> - `addons/level_designer/level_canvas.gd` — `_gui_input`/`_try_append` 现状
> **生成日期**: 2026-07-12

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-12 |
| 状态 | 实施级 spec,待用户审 → writing-plans |
| 产物路径 | `docs/superpowers/specs/2026-07-12-level-tool-drag-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming(范围决策)→ 本文档 → writing-plans |
| 上游 | 设计级 spec §7、canvas 现状 |
| 下游 | writing-plans 逐步实施计划 |

## 1. 范围

**纳入**:
- LevelCanvas NONE 模式拖拽画路径(按下 + 移动 + 释放)
- `_dragging` 标志;`_gui_input` 处理 `InputEventMouseMotion`

**不纳入**:
- 拖拽补间跳格(快速移动跳格不补,用户慢拖可覆盖)
- 拖拽用于其他模式(机制/障碍保持点击)
- 整笔 undo(用逐格 undo)

## 2. 关键决策与理由(避免长期遗忘)

| # | 决策 | 理由 | 弃选替代及其原因 |
|---|---|---|---|
| D1 | 拖拽仅 NONE 模式 | 画路径是高频长操作,拖拽收益最大;机制/障碍标注点击已够 | 全模式拖拽:机制标注拖拽语义不清、易误标 |
| D2 | 逐格 undo(复用 `_try_append` 的 `push_undo`) | 简单,复用现有;拖一笔 N 格则 undo N 次撤完 | 整笔 undo:需记录拖拽起止边界,复杂 |
| D3 | 不补跳格 | 慢拖即可覆盖;补间算法(Bresenham 等)过度 | 插值补格:复杂、路径优先法不需精确补 |

## 3. 实现

**LevelCanvas**:
- `var _dragging: bool = false`
- `_gui_input`:
  - `InputEventMouseButton` LEFT `pressed` → `_dragging = true`;若 `mode == NONE`:`_try_append(coord)`
  - `InputEventMouseButton` LEFT `released` → `_dragging = false`
  - `InputEventMouseMotion` and `_dragging` and `mode == NONE` → `_try_append(coord)`
- `_try_append` 已含邻接/不重复校验 + `push_undo`,拖拽直接复用

> 拖拽经过非邻接/重复格会被 `_try_append` 自动忽略,保证 path 合法。

## 4. 任务切片(TDD,喂给 writing-plans)

| # | 模块 | 红→绿 | 测试 |
|---|---|---|---|
| 1 | `level_canvas.gd` `_gui_input` 拖拽 | 手动:拖拽画连续路径 | 手动 |

> 拖拽是 @tool 表现层交互,无纯逻辑可抽(`_try_append` 已被 undo 测试覆盖),手动验证。

## 5. 验收

- [ ] NONE 模式拖拽画连续路径(按下+移动+释放)
- [ ] 拖拽画的格可逐格 undo
- [ ] 其他模式(机制/障碍)点击行为不变
