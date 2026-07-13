# 设计规范:monk 首批关卡「闭环优先留的债」清理

> **任务来源**: 首批 8 关 headless 产关已 merge main(25f1be9)+ push,126 测试绿。原 spec(`2026-07-12-first-levels-generation-design.md` §8)因闭环优先留 3 类设计感债:① 1-2/1-3 雷同(均 5×5 random_walk);② 门机关关(2-1/2/3)heuristic 全空无假山;③ 2-3 无指定终点。用户选择「全清 3 类债」,经 brainstorm 确认方案。
> **任务内容**: 定义 3 类债的具体清理方案、random_walk 路径长度保证机制、守门与验证。
> **参考文档**:
> - `docs/superpowers/specs/2026-07-12-first-levels-generation-design.md` — 首批产关主 spec(§8 技术债章节,本 spec 是其具体化执行)
> - `docs/superpowers/plans/2026-07-13-first-levels-generation.md` — 首批产关 plan(generate_first_levels.gd 现状)
> - `scripts/tool/path_generator.gd` — `generate_random_walk`(贪心随机走,无回溯)
> **生成日期**: 2026-07-13

| 字段 | 值 |
|---|---|
| 日期 | 2026-07-13 |
| 状态 | 设计已确认,待 spec 复核 |
| 产物路径 | 本文件 |
| 产出流程 | superpowers:brainstorming →(用户确认)→ 写 spec →(复核)→ writing-plans → 实施 |
| 上游 | first-levels-generation spec §8、path_generator.gd |

## 1. 背景与目标

首批产关为「闭环优先」(脚本一次跑通、天然可解、不追求设计感)留了 3 类债。本 spec 清理它们,提升关卡设计感,使其更贴近 first-levels-and-select spec §8 蓝图:

1. **债 1(1-2/1-3 雷同)**:二者均 5×5 `random_walk` 不指定 end,路径形状随机,布局可能雷同 → 1-3 加瓶颈 WALL 区分
2. **债 2(门机关全空)**:2-1/2-2/2-3 用 `heuristic` 全图 path → Filler 无非 path 格可填 → 全空网格 → 改 `random_walk` 部分路径,Filler 自动填假山+水
3. **债 3(2-3 无终点)**:2-3 用 heuristic 全图、goal 不限 → 改 `random_walk(start, end=(6,6))` 指定终点

**前提确认(探索结论)**:
- 加假山 / 改终点**不破坏可解性** —— 路径优先法:path 是解;`obstacle_overrides` 只对「非 path 格」生效;改终点仅设 `goal=path[-1]`。path 连通性不动
- `generate_random_walk` 不指定 end 是**贪心随机走**(无回溯),6×6 上通常 ~20 格(留 ~16 格)→ Filler 自动产 `border WALL + inner 流水`,天然满足债 2 的「有障碍」
- 摆 lever/door 需 path >= ~9 格;6×6 贪心 < 9 格罕见 → 脚本重试兜底

## 2. 关键决策摘要

| # | 决策点 | 决策 | 理由 | 否决的替代 |
|---|---|---|---|---|
| D1 | random_walk 长度保证 | **方案 A:脚本内重试** `_gen_path_with_min` 循环 random_walk 直到 `path.size() >= min` | 不动 `PathGenerator`(外科手术式原则);贪心 6×6 通常 >= min,重试 1~3 次即够 | B:PathGenerator 加 `min_length` 参数(改工具 + 同步 test_path_generator/LevelDesigner,侵入大);C:门机关关保持 heuristic 全空放弃债 2(违背用户「全清」) |
| D2 | 债 2 障碍来源 | **Filler 自动**(border WALL + inner 流水,~16 格) | 简单,天然满足「有障碍」区分全空;闭环清债不追求 spec §8「少量」精确 | 手动 `obstacle_overrides` 指定假山(需选非 path 格 + 数量,复杂;且闭环优先不必精控数量) |
| D3 | 确定性 | 不加 seed,`.tres` 存盘固化 | 同首批(G6);避免改 `PathGenerator` 签名 | 加 seed(改 generate_random_walk 签名,影响工具与测试) |
| D4 | 重试失败处理 | 用最后一次 path + `push_warning`(不中断) | 兜底降级,极端情况仍产出可玩关(而非脚本失败) | 失败即 `quit(1)`(首批产关要求一次跑通,清债阶段降级更友好) |

## 3. 3 类债处理(全改 `scripts/tool/generate_first_levels.gd`)

### 3.1 债 1:1-3 加瓶颈 WALL

1-3 `random_walk` 5×5 产 path 后,在「中央区域」(如 `(1..3, 1..3)`)选 1~2 个**非 path 格**设 `obstacle_overrides[coord] = "WALL"`,制造瓶颈区分 1-2。

> override 格必须在 path_set 之外(Filler 仅对非 path 格应用 override)。脚本遍历中央格,过滤掉 path 上的,取**至多 2 个**(可用不足则取实际可用数)。

### 3.2 债 2:门机关关改 random_walk + Filler 自动假山

`_level_def()` 中 2-1/2-2/2-3 的 `gen` 由 `"heuristic"` 改 `"walk"`(不指定 end);用 D1 的 `_gen_path_with_min(size, start, end=不限, min=12)` 产 path(min=12:摆 2 lever+2 door 需 ~9 格 + 间距余量)。path 不覆盖全图 → Filler 自动填 `border WALL + inner 流水` = 假山+水(D2)。lever/door 摆位逻辑不变(`_make_lever_doors`,path 前/后段)。

### 3.3 债 3:2-3 指定终点

`_level_def()` 中 2-3 改:`goal = Vector2i(6, 6)`、`gen = "walk"`;`_gen_path_with_min(7×7, (0,0), end=(6,6), min=15)`(7×7=49 格,min=15 留充足假山空间且保证摆位)。`has_goal=true`,`goal=path[-1]=(6,6)`(`_dfs_to_end` 保证到达)。

### 3.4 长度保证 `_gen_path_with_min`

```gdscript
func _gen_path_with_min(size, start, end, min_len, max_tries=20) -> Array[Vector2i]:
    var best: Array[Vector2i] = []
    for i in range(max_tries):
        var p := PathGenerator.generate_random_walk(size, start, end)
        if p.size() > best.size(): best = p
        if p.size() >= min_len: return p
    push_warning("random_walk 未达 min_len=%d,用最长 %d" % [min_len, best.size()])
    return best
```

## 4. 守门与验证(同首批,无新增测试)

- 产关脚本内:`MechanicOrderValidator.validate`(门机关关)+ `LevelSystem.validate`(每关),失败 `push_error + _exit_code=1`
- GUT:`test_first_levels_generated`(契约:id/display/difficulty/章引用/机制数量 —— **机制数量不变,契约测试不需改**)+ `test_levels_valid`(遍历 levels/*.tres,自动覆盖)
- 可解性:路径优先法保证

> 债 1 加 WALL / 债 2 改 random_walk / 债 3 改终点 均不改变 `meta.id` / `mechanics` 数量 / 章引用 → `test_first_levels_generated` 契约不变。

## 5. 验收

- [ ] 重跑产关脚本无 `push_error`(允许 D4 `push_warning`),8 关重新产出:1-3 有瓶颈 WALL、2-1/2/3 有假山+水、2-3 goal=(6,6)
- [ ] GUT 126/126 绿(契约不变 + test_levels_valid)
- [ ] 用户 QA:1-3 与 1-2 视觉区分;门机关关有障碍绕行;2-3 指定终点收紧

## 6. 后续 / 剩余技术债

- random_walk 仍无 seed(D3);重跑覆盖会变,存盘固化
- 关卡难度量化、求解器(D8,待单独 brainstorm)、LevelDesigner 工具完善 —— 见 first-levels-and-select spec §12
