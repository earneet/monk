# 首批关卡「闭环优先留的债」清理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 清理首批关卡 3 类设计感债(1-3 雷同 / 门机关全空 / 2-3 无终点),改 `generate_first_levels.gd` 重跑覆盖 `.tres`。

**Architecture:** 改 `_level_def`(2-1/2-3 `gen` heuristic→walk;2-3 `goal=(6,6)`)+ `_gen_path`(门机关关用新 `_gen_path_with_min` 重试保证长度,纯路径关 random_walk 不变)+ `_build_level`(1-3 调 `_add_bottleneck` 加瓶颈 WALL)。Filler 自动把门机关关非 path 格填成假山+水。重跑覆盖 `.tres`。

**Tech Stack:** Godot 4.7 / 纯 GDScript / GUT 9.7

**Spec:** `docs/superpowers/specs/2026-07-13-first-levels-debt-cleanup-design.md`

**环境:**
- `GODOT="C:\Program Files\godot_engine\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64.exe"`
- 从 `main` 建分支 `feat/levels-debt-cleanup` 执行

---

## File Structure

- Modify: `scripts/tool/generate_first_levels.gd`(`_level_def` 改 3 行 + `_gen_path` 重写 + 新增 `_gen_path_with_min` / `_add_bottleneck` + `_build_level` 加 1 处调用)
- Modify: `tests/tool/test_first_levels_generated.gd`(加 2 个契约测试)
- Modify(脚本重跑覆盖产物):`resources/levels/l1_3.tres`、`l2_1.tres`、`l2_2.tres`、`l2_3.tres`(以及随机性连带变化的 `l1_2.tres`、`l1_4.tres`、`l1_5.tres`)

**职责边界:** 仅改产关脚本数据/参数 + 加长度保证与瓶颈两个纯函数;不动 `PathGenerator` / `Filler` / `Exporter`(外科手术式)。契约测试只验「可精确断言」的债 2(门机关有障碍)/ 债 3(2-3 终点);债 1(1-3 瓶颈)因 random_walk 本有障碍、难精确区分,靠人工 QA。

---

### Task 1: 加失败测试(债 2 / 债 3 可测部分)

**Files:**
- Modify: `tests/tool/test_first_levels_generated.gd`(末尾追加 2 测试)

- [ ] **Step 1: 追加 2 个测试**

在文件末尾追加:

```gdscript
func test_door_levels_have_obstacles() -> void:
    var door_files := ["l2_1", "l2_2", "l2_3"]
    for f in door_files:
        var lr := load("res://resources/levels/%s.tres" % f) as LevelResource
        assert_not_null(lr, "%s 应存在" % f)
        var has_obstacle := false
        for y in range(lr.size.y):
            for x in range(lr.size.x):
                if lr.tiles[y][x] != LevelResource.TileType.EMPTY:
                    has_obstacle = true
                    break
            if has_obstacle:
                break
        assert_true(has_obstacle, "%s 应有障碍(非全空)" % f)

func test_l2_3_has_goal() -> void:
    var lr := load("res://resources/levels/l2_3.tres") as LevelResource
    assert_not_null(lr, "l2_3 应存在")
    assert_eq(lr.goal, Vector2i(6, 6), "l2_3 应指定终点 (6,6)")
```

- [ ] **Step 2: 跑测试,确认 FAIL**

Run:
```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_first_levels_generated -gexit
```
Expected: FAIL —— `test_door_levels_have_obstacles`(2-1/2/3 现状 heuristic 全空)+ `test_l2_3_has_goal`(2-3 现状 goal=(-1,-1))。

---

### Task 2: 改产关脚本 + 重跑

**Files:**
- Modify: `scripts/tool/generate_first_levels.gd`

- [ ] **Step 1: `_level_def` 改 2-1/2-2/2-3 三行(heuristic→walk;2-3 goal=(6,6))**

old:
```gdscript
        _def("l2_1", "2-1", "叩门", 6, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", ["lv1"]),
        _def("l2_2", "2-2", "重门", 7, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", ["lv1", "lv2"]),
        _def("l2_3", "2-3", "后山终", 8, Vector2i(7, 7), Vector2i(0, 0), Vector2i(-1, -1), "heuristic", ["lv1"]),
```
new:
```gdscript
        _def("l2_1", "2-1", "叩门", 6, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "walk", ["lv1"]),
        _def("l2_2", "2-2", "重门", 7, Vector2i(6, 6), Vector2i(0, 0), Vector2i(-1, -1), "walk", ["lv1", "lv2"]),
        _def("l2_3", "2-3", "后山终", 8, Vector2i(7, 7), Vector2i(0, 0), Vector2i(6, 6), "walk", ["lv1"]),
```

- [ ] **Step 2: 重写 `_gen_path` + 新增 `_gen_path_with_min`**

old:
```gdscript
func _gen_path(def: Dictionary) -> Array[Vector2i]:
    var gen: String = def["gen"]
    var size: Vector2i = def["size"]
    if gen == "heuristic":
        return PathGenerator.generate_heuristic(size)
    var start: Vector2i = def["start"]
    var goal: Vector2i = def["goal"]
    var end := goal if goal.x >= 0 else Vector2i(-1, -1)
    return PathGenerator.generate_random_walk(size, start, end)
```
new:
```gdscript
func _gen_path(def: Dictionary) -> Array[Vector2i]:
    var gen: String = def["gen"]
    var size: Vector2i = def["size"]
    if gen == "heuristic":
        return PathGenerator.generate_heuristic(size)
    var start: Vector2i = def["start"]
    var goal: Vector2i = def["goal"]
    var end := goal if goal.x >= 0 else Vector2i(-1, -1)
    var lever_ids: Array = def["lever_ids"]
    if lever_ids.is_empty():
        return PathGenerator.generate_random_walk(size, start, end)
    var min_len: int = 15 if size.x >= 7 else 12
    return _gen_path_with_min(size, start, end, min_len)


func _gen_path_with_min(size: Vector2i, start: Vector2i, end: Vector2i, min_len: int, max_tries: int = 20) -> Array[Vector2i]:
    var best: Array[Vector2i] = []
    for i in range(max_tries):
        var p := PathGenerator.generate_random_walk(size, start, end)
        if p.size() > best.size():
            best = p
        if p.size() >= min_len:
            return p
    push_warning("random_walk 未达 min_len=%d,用最长 %d" % [min_len, best.size()])
    return best
```

- [ ] **Step 3: `_build_level` 加 1-3 瓶颈调用**

old:
```gdscript
    wlr.path = _gen_path(def)
    var goal: Vector2i = def["goal"]
    wlr.has_goal = goal.x >= 0
```
new:
```gdscript
    wlr.path = _gen_path(def)
    if meta_id == "1-3":
        _add_bottleneck(wlr)
    var goal: Vector2i = def["goal"]
    wlr.has_goal = goal.x >= 0
```

- [ ] **Step 4: 新增 `_add_bottleneck` 函数**(放在 `_make_lever_doors` 之后)

```gdscript
func _add_bottleneck(wlr: WorkLevelResource) -> void:
    var path_set: Dictionary = {}
    for c in wlr.path:
        path_set[c] = true
    var added := 0
    for y in range(1, wlr.size.y - 1):
        for x in range(1, wlr.size.x - 1):
            var coord := Vector2i(x, y)
            if not path_set.has(coord):
                wlr.obstacle_overrides[coord] = "WALL"
                added += 1
                if added >= 2:
                    return
```

- [ ] **Step 5: import**

Run:
```bash
"$GODOT" --headless --path . --import
```
Expected: exit 0(脚本无语法错误)。

- [ ] **Step 6: 重跑产关脚本**

Run:
```bash
"$GODOT" --headless --path . -s res://scripts/tool/generate_first_levels.gd
```
Expected: 8 关 + 2 章产出,exit 0;允许 `push_warning`(random_walk 未达 min 的极端情况),**不允许 `push_error`**。

- [ ] **Step 7: 跑契约测试,确认 PASS**

Run:
```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gselect=test_first_levels_generated -gexit
```
Expected: PASS —— 原 3 + 新 2(test_door_levels_have_obstacles / test_l2_3_has_goal)全绿。

- [ ] **Step 8: commit 脚本 + 测试 + 重跑产物**

```bash
git add scripts/tool/generate_first_levels.gd tests/tool/test_first_levels_generated.gd \
        resources/levels/l1_2.tres resources/levels/l1_3.tres resources/levels/l1_4.tres \
        resources/levels/l1_5.tres resources/levels/l2_1.tres resources/levels/l2_2.tres \
        resources/levels/l2_3.tres
git commit -m "$(cat <<'EOF'
refactor(level): 清理首批关卡设计感债(1-3瓶颈+门机关假山+2-3终点)

债1:1-3 加 _add_bottleneck 在内部非path格设WALL瓶颈区分1-2。
债2:2-1/2/3 gen heuristic→walk(部分路径),Filler自动填假山+水;
_gen_path_with_min 重试保证 path>=min(12/15)稳定摆lever/door。
债3:2-3 改 random_walk(end=(6,6)) 指定终点。
test_first_levels_generated 加 door_levels_have_obstacles + l2_3_has_goal。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

> 注:1-1 是 heuristic 全图(无随机),不变。chapter_01/02.tres 用 `ext_resource` 引用关卡(非内联),关卡内容覆盖不改变 chapter 文件本身(git 无 diff),故不入 add 列表。

---

### Task 3: 全量回归 + QA 交付

- [ ] **Step 1: GUT 全量回归**

Run:
```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: 全绿(原 126 + 新 2 = 128)。`test_levels_valid` 自动覆盖重跑后的 8 关。

- [ ] **Step 2: 提交 spec + plan**

```bash
git add docs/superpowers/specs/2026-07-13-first-levels-debt-cleanup-design.md \
        docs/superpowers/plans/2026-07-13-first-levels-debt-cleanup.md
git commit -m "$(cat <<'EOF'
docs(level): 首批关卡设计感债清理 spec + plan

spec:3类债(D1脚本重试/D2 Filler自动/D3无seed/D4降级)+ 决策理由。
plan:TDD 三任务(契约测试→改脚本重跑→回归交付)。128/128 绿。

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: 端到端人工 QA(用户)**

F5 跑游戏确认:
- [ ] 1-3 与 1-2 视觉有区分(1-3 内部有 WALL 瓶颈)
- [ ] 2-1/2-2/2-3 有假山+流水障碍(非全空),踩机关后门可通行
- [ ] 2-3 须到达指定终点 (6,6) 才通关
- [ ] 难度递进顺畅,无死局挫败

> QA 反馈:某关不满意 → 改 `generate_first_levels.gd` 参数(min_len / 瓶颈数量 / 终点)重跑。

---

## Self-Review

**1. Spec coverage:** D1(_gen_path_with_min)→ Task 2 Step 2 ✓;D2(门机关 gen→walk,Filler 自动)→ Step 1 ✓;D3(无 seed)→ 不引入 seed ✓;D4(降级 push_warning)→ Step 2 `_gen_path_with_min` ✓;债 1(1-3 瓶颈)→ Step 3/4 ✓;债 2 → Step 1 ✓;债 3 → Step 1 ✓;守门 → 脚本既有(MechanicOrderValidator + LevelSystem.validate)未动 ✓;验收 → Task 3 ✓。

**2. Placeholder scan:** 无 TBD;所有 step 含完整代码 / 命令 / expected。

**3. Type consistency:** `_gen_path_with_min(size: Vector2i, start: Vector2i, end: Vector2i, min_len: int, max_tries: int = 20) -> Array[Vector2i]` 与 `_gen_path` 调用一致;`_add_bottleneck(wlr: WorkLevelResource)` 与 `_build_level` 调用一致;`obstacle_overrides[coord] = "WALL"` 与 `Filler._override_tile` 的 `"WALL"` 分支一致。
