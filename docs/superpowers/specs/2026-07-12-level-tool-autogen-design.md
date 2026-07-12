# 实施设计:monk 关卡设计工具增量——自动生成哈密顿路径

> **任务来源**: 「全做」4 子增量第 4 个/最后(undo/obstacle/drag 已完成,drag merge=01ab2e6,94 测试绿)。用户要求**三种生成算法都支持**(螺旋/Hilbert/启发式),非单选。本 spec 是自动生成子批次。
> **任务内容**: 关卡工具加自动生成——按所选算法(螺旋/Hilbert/启发式)生成覆盖整个网格的哈密顿路径作起点,用户再调整/标机制。
> **参考文档**:
> - `docs/project/2026-07-09-level-design-tool-design.md` — §7 路径输入(自动随机生成 LD4)、§13 算法选型(螺旋/分形/启发式)
> - `docs/superpowers/specs/2026-07-12-level-design-tool-mvp-design.md` — MVP spec(WorkLevelResource.path)
> - `scripts/tool/` + `addons/level_designer/main_view.gd` — 现状
> **生成日期**: 2026-07-12

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-12 |
| 状态 | 实施级 spec,待用户审 → writing-plans |
| 产物路径 | `docs/superpowers/specs/2026-07-12-level-tool-autogen-design.md`(本文件) |
| 产出流程 | superpowers:brainstorming(三算法全做 + 边界决策)→ 本文档 → writing-plans |
| 上游 | 设计级 spec §7/§13、MVP spec、现状代码 |
| 下游 | writing-plans 逐步实施计划 |

## 1. 范围

**纳入**:
- `PathGenerator`(scripts/tool/):三个纯函数 `generate_spiral(size)` / `generate_hilbert(size)` / `generate_heuristic(size)` -> Array[Vector2i]
- MainView「生成」按钮 + 算法下拉(螺旋/Hilbert/启发式)
- 生成覆盖 work.path + push_undo(恢复旧 path)
- 三算法 GUT 测试

**不纳入**:
- 框选子区域生成(仅整个网格)
- 算法参数化(如螺旋方向、启发式种子;固定行为)

## 2. 关键决策与理由(避免长期遗忘)

| # | 决策 | 理由 | 弃选替代及其原因 |
|---|---|---|---|
| D1 | 三算法全做(螺旋/Hilbert/启发式) | 用户明确要三者都支持;各算法纯函数独立,可分别 TDD;UI 下拉切换 | 单算法:用户不想只选一个;多 spec 分批:三算法耦合度高,一起做更内聚 |
| D2 | Hilbert 非 2ⁿ 尺寸退化螺旋 | Hilbert 需边长 2ⁿ;非 2ⁿ 退化螺旋保证总有输出 + 提示 | 报错拒生成:用户体验差;适配填充裁剪:复杂 |
| D3 | 启发式 Warnsdorff + 回溯,重试 N 次 | Warnsdorff 几乎总成功;回溯兜底罕见死路;重试提升成功率 | 纯随机:易死路;不重试:失败率偏高 |
| D4 | 生成覆盖 work.path + push_undo(恢复旧) | 生成是新起点,覆盖合理;push_undo 可撤销恢复旧 path | 追加:与已有 path 拼接语义混乱 |

## 3. 算法

### 螺旋 generate_spiral(size)
从 (0,0) 起,顺时针外圈向内螺旋,逐格收集。确定性,矩形总能生成 size.x*size.y 格。

### Hilbert generate_hilbert(size)
- 边长为 2ⁿ(`size.x == size.y` 且 `is_power_of_2(size.x)`):递归生成 Hilbert 曲线
- 否则:退化 `generate_spiral(size)`(D2)

### 启发式 generate_heuristic(size)
Warnsdorff 规则:从 (0,0) 起,每步选**未访问邻居中出口最少**的格(出口=该邻居的未访问邻居数);死路则回溯。重试 N 次(每次起点的邻居顺序随机化),成功即返回;N 次失败返回空数组(调用方不覆盖)。

## 4. UI(MainView)

- 工具栏加:算法下拉(螺旋/Hilbert/启发式) + 「生成」按钮
- `_on_generate`:按所选算法 `PathGenerator.generate_xxx(size)` → 若返回非空:`work.push_undo(恢复旧 path)` + `work.path = 生成路径` + `canvas.queue_redraw()` + `_refresh_lever_options()`;空(print 提示,不覆盖)

## 5. 任务切片(TDD,喂给 writing-plans)

| # | 模块 | 红测 → 绿 | 测试 |
|---|---|---|---|
| 1 | `generate_spiral` | 覆盖全格/邻接/不重复/起 (0,0) | GUT |
| 2 | `generate_hilbert` | 2ⁿ 尺寸覆盖全格;非 2ⁿ 退化 spiral | GUT |
| 3 | `generate_heuristic` | 覆盖全格/邻接/不重复(成功情况) | GUT |
| 4 | MainView 生成按钮 + 下拉 | 手动:选算法→生成→覆盖 path→可 undo | 手动 |

## 6. 验收

- [ ] 三算法各自 GUT 覆盖(覆盖全格/邻接/不重复)
- [ ] Hilbert 非 2ⁿ 退化螺旋
- [ ] 启发式失败时不覆盖 + 提示
- [ ] 生成按钮手动可用,生成后可 undo 恢复

## 执行中变更(D3 简化,2026-07-12)

D3 原「启发式 Warnsdorff + 回溯重试 N 次」简化为**纯 DFS 回溯**:
- **变更**:`generate_heuristic` 用确定性 DFS(从 (0,0),右下左上顺序,死路回溯),非 Warnsdorff。
- **理由**:DFS 保证找到哈密顿路径(若存在)→ GUT 测试稳定(确定性);Warnsdorff 随机性使测试不确定 + 实现复杂。DFS 对工具用的小网格足够快;随机/Warnsdorff 留后续。
- **实际代码**:`scripts/tool/path_generator.gd` `_dfs`。§3 启发式描述以本变更为准。
