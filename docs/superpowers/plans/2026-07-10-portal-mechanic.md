# 传送机制(PortalData)批次 2 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现传送门 PortalData——踏入口后系统自动追加配对端、undo 撤两步、pair_id 成对校验、起点/goal 禁传送、GridRenderer 配对连线表现。

**Architecture:** PortalData 继承 MechanicData 零 override(机制性全在 PathState.move 自动追加);MechanicSystem 加 `_portal_pairs` 中心化索引 + `pair_of`/`portal_pairs` 查询(对称 `_lever_cells`);PathState.move 末尾追加出口、undo 用 `pair_of(new_last)==popped` 精确撤两步;LevelSystem load 注入 + validate 五类校验;GridRenderer 紫块+标号+连线。

**Tech Stack:** Godot 4.7 stable / 纯 GDScript / GUT 9.7.0 / Forward+

---

## 前置约定(所有 Task 通用)

- **分支**: `feat/portal-batch2`(已建,自 main a971b8b)。全程在此分支。
- **Godot 可执行**(bash 不持久环境变量,命令内写全路径):
  `GODOT="C:/Program Files/godot_engine/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64.exe"`
- **跑全部 GUT 测试**:
  ```bash
  "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
  ```
- **改/加 `class_name` 后必须先 import**(GDScript 4.7 严格推断):
  ```bash
  "$GODOT" --headless --path . --import
  ```
- **规范 §3.3 已于 spec 阶段同步**(commit 1f48855,传送归自动追加、入口三层=不重复/邻接/机制通行),本计划不再改规范。
- **TDD**: 每 Task 先写失败测试 → 跑(红)→ 最小实现 → 跑(绿)→ commit。跑测试用「跑全部」命令(新测试 fail 即红、全 pass 即绿,且自带回归保护)。
- **GDScript 风格**: 4 空格缩进;snake_case;默认不加注释(除非解释「为什么」)。
- **代码块缩进**: 本计划代码块为可读性用 tab 显示;实现写入 `.gd` 时一律转 4 空格(与 `scripts/grid/path_state.gd` 等项目代码一致)。

---

## Task 1: PortalData + MechanicSystem 配对索引/查询

**Files:**
- Create: `scripts/mechanics/portal_data.gd`
- Modify: `scripts/mechanics/mechanic_system.gd`
- Create: `tests/mechanics/test_portal_data.gd`

- [ ] **Step 1: 写失败测试** — Create `tests/mechanics/test_portal_data.gd`

```gdscript
extends GutTest

func test_portal_default_can_pass_true():
    var ms := MechanicSystem.new()
    var p := PortalData.new()
    p.coord = Vector2i(1, 0)
    ms.set_data(Vector2i(1, 0), p)
    assert_true(ms.can_pass(Vector2i(1, 0), []))

func test_portal_counts_for_need_cover():
    var p := PortalData.new()
    assert_true(p.counts_for_need_cover())

func test_register_and_pair_of():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(2, 0), Vector2i(5, 5))
    assert_eq(ms.pair_of(Vector2i(2, 0)), Vector2i(5, 5))
    assert_eq(ms.pair_of(Vector2i(5, 5)), Vector2i(2, 0))

func test_pair_of_unregistered_returns_self():
    var ms := MechanicSystem.new()
    assert_eq(ms.pair_of(Vector2i(9, 9)), Vector2i(9, 9))

func test_portal_pairs_dedup():
    var ms := MechanicSystem.new()
    ms.register_portal(Vector2i(0, 0), Vector2i(1, 1))
    var pairs: Array = ms.portal_pairs()
    assert_eq(pairs.size(), 1)
    var pair: Array = pairs[0]
    assert_true(pair.has(Vector2i(0, 0)) and pair.has(Vector2i(1, 1)))
```

- [ ] **Step 2: 跑测试验证失败(红)**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL —— `PortalData` 未定义(class 不存在)、`register_portal`/`pair_of`/`portal_pairs` 方法不存在。

- [ ] **Step 3: 实现 PortalData** — Create `scripts/mechanics/portal_data.gd`

```gdscript
class_name PortalData
extends MechanicData

@export var pair_id: String
```

- [ ] **Step 4: 实现 MechanicSystem 配对索引** — Modify `scripts/mechanics/mechanic_system.gd`

在 `var _lever_cells` 下一行加字段;在 `is_lever_pressed` 函数之后追加三个方法:

```gdscript
var _portal_pairs: Dictionary = {}  # coord(Vector2i) -> 配对coord(双向)
```

```gdscript
func register_portal(a: Vector2i, b: Vector2i) -> void:
	_portal_pairs[a] = b
	_portal_pairs[b] = a

func pair_of(coord: Vector2i) -> Vector2i:
	return _portal_pairs.get(coord, coord)

func portal_pairs() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for key in _portal_pairs:
		var a: Vector2i = key
		var b: Vector2i = _portal_pairs[key]
		var k1 := "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]
		var k2 := "%d,%d-%d,%d" % [b.x, b.y, a.x, a.y]
		if not seen.has(k1) and not seen.has(k2):
			result.append([a, b])
			seen[k1] = true
	return result
```

- [ ] **Step 5: import(新增 class_name PortalData)**

Run: `"$GODOT" --headless --path . --import`
Expected: 无错误退出。

- [ ] **Step 6: 跑测试验证通过(绿)**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部通过(原 38 + 新增 5)。

- [ ] **Step 7: Commit**

```bash
git add scripts/mechanics/portal_data.gd scripts/mechanics/mechanic_system.gd tests/mechanics/test_portal_data.gd
git commit -m "feat(mechanics): PortalData + MechanicSystem 配对索引/查询(TDD)"
```

---

## Task 2: PathState.move 自动追加配对端(决策 A)

**Files:**
- Modify: `scripts/grid/path_state.gd`
- Modify: `tests/grid/test_path_state.gd`(追加测试)

- [ ] **Step 1: 写失败测试** — 追加到 `tests/grid/test_path_state.gd` 末尾

```gdscript
func test_move_into_portal_appends_peer():
	var ms := MechanicSystem.new()
	ms.register_portal(Vector2i(2, 0), Vector2i(2, 1))
	var px := PortalData.new()
	px.coord = Vector2i(2, 0)
	px.pair_id = "P1"
	ms.set_data(Vector2i(2, 0), px)
	var ps := _ps(ms, _gm3())
	assert_true(ps.move(Vector2i(1, 0)))
	assert_true(ps.move(Vector2i(2, 0)))
	assert_eq(ps.path.size(), 4)
	assert_eq(ps.path[2], Vector2i(2, 0))
	assert_eq(ps.path[3], Vector2i(2, 1))

func test_move_into_portal_peer_already_in_path_rolls_back():
	var ms := MechanicSystem.new()
	ms.register_portal(Vector2i(2, 0), Vector2i(1, 0))
	var px := PortalData.new()
	px.coord = Vector2i(2, 0)
	px.pair_id = "P1"
	ms.set_data(Vector2i(2, 0), px)
	var ps := _ps(ms, _gm3())
	ps.move(Vector2i(1, 0))
	assert_false(ps.move(Vector2i(2, 0)))
	assert_eq(ps.path.size(), 2)
```

> 第二个测试构造异常(入口 X=(2,0) 的配对端被设为已踩的 (1,0))→ 命中 fail-safe 回滚,move 失败、path 不留入口半态。

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 两个新测试 FAIL —— `path.size()` 为 3(未追加 peer)/ 第二个 `assert_false` 失败。

- [ ] **Step 3: 实现 move 自动追加** — Modify `scripts/grid/path_state.gd`

把现有 `move` 函数的末尾三行(`path.append(coord)` / `_emit()` / `return true`)替换为:

```gdscript
	path.append(coord)
	if not _append_portal_peer(coord):
		return false
	_emit()
	return true
```

并在 `move` 函数之后新增:

```gdscript
func _append_portal_peer(coord: Vector2i) -> bool:
	if not (_ms.data_at(coord) is PortalData):
		return true
	var peer: Vector2i = _ms.pair_of(coord)
	if peer in path:
		path.pop_back()
		return false
	path.append(peer)
	return true
```

- [ ] **Step 4: 跑测试验证通过(绿)**

Run: 全部测试命令
Expected: 全部通过(回归:`test_move_valid_appends` 等仍绿;新增 2 绿)。

- [ ] **Step 5: Commit**

```bash
git add scripts/grid/path_state.gd tests/grid/test_path_state.gd
git commit -m "feat(grid): PathState.move 踏传送门自动追加配对端 + fail-safe 回滚(TDD)"
```

---

## Task 3: PathState.undo 撤两步(决策 A1)

**Files:**
- Modify: `scripts/grid/path_state.gd`
- Modify: `tests/grid/test_path_state.gd`(追加测试)

- [ ] **Step 1: 写失败测试** — 追加到 `tests/grid/test_path_state.gd` 末尾

```gdscript
func _ps_with_portal_pair() -> PathState:
	var ms := MechanicSystem.new()
	ms.register_portal(Vector2i(2, 0), Vector2i(2, 1))
	var px := PortalData.new()
	px.coord = Vector2i(2, 0)
	px.pair_id = "P1"
	ms.set_data(Vector2i(2, 0), px)
	return _ps(ms, _gm3())

func test_undo_portal_pair_rolls_back_two():
	var ps := _ps_with_portal_pair()
	ps.move(Vector2i(1, 0))
	ps.move(Vector2i(2, 0))
	ps.undo()
	assert_eq(ps.path.size(), 2)
	assert_eq(ps.path[1], Vector2i(1, 0))

func test_undo_consecutive_portals_only_last_intent():
	var ms := MechanicSystem.new()
	ms.register_portal(Vector2i(2, 0), Vector2i(2, 1))
	ms.register_portal(Vector2i(1, 1), Vector2i(1, 2))
	var p1 := PortalData.new()
	p1.coord = Vector2i(2, 0)
	p1.pair_id = "P1"
	ms.set_data(Vector2i(2, 0), p1)
	var p2 := PortalData.new()
	p2.coord = Vector2i(1, 1)
	p2.pair_id = "P2"
	ms.set_data(Vector2i(1, 1), p2)
	var ps := _ps(ms, _gm3())
	ps.move(Vector2i(1, 0))
	ps.move(Vector2i(2, 0))
	ps.move(Vector2i(1, 1))
	ps.undo()
	assert_eq(ps.path.size(), 4)
	assert_eq(ps.path[3], Vector2i(2, 1))
```

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 两个新测试 FAIL —— 现 `undo` 只 pop 一格,`path.size()` 为 3/5 而非 2/4。

- [ ] **Step 3: 实现 undo 撤两步** — Modify `scripts/grid/path_state.gd`

替换整个 `undo` 函数为:

```gdscript
func undo() -> void:
	if path.size() <= 1:
		return
	var popped: Vector2i = path[path.size() - 1]
	path.pop_back()
	var new_last: Vector2i = path[path.size() - 1]
	if _ms.data_at(new_last) is PortalData and _ms.pair_of(new_last) == popped:
		path.pop_back()
	_emit()
```

- [ ] **Step 4: 跑测试验证通过(绿)**

Run: 全部测试命令
Expected: 全部通过(回归:`test_undo_rolls_back` 仍绿;新增 2 绿)。

- [ ] **Step 5: Commit**

```bash
git add scripts/grid/path_state.gd tests/grid/test_path_state.gd
git commit -m "feat(grid): PathState.undo 传送对撤两步(pair_of==popped 判据,TDD)"
```

---

## Task 4: LevelSystem 注入配对 + validate 五类校验

**Files:**
- Modify: `scripts/level/level_system.gd`
- Modify: `tests/level/test_level_system.gd`(追加测试)

- [ ] **Step 1: 写失败测试** — 追加到 `tests/level/test_level_system.gd` 末尾

```gdscript
func _portal(pair_id: String, coord: Vector2i) -> PortalData:
	var p := PortalData.new()
	p.pair_id = pair_id
	p.coord = coord
	return p

func test_load_registers_portal_pair():
	var lr := _flat_level(3, 1)
	lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
	lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
	var ls := LevelSystem.new()
	ls.load(lr)
	assert_eq(ls.mechanic_system.pair_of(Vector2i(1, 0)), Vector2i(2, 0))

func test_validate_rejects_lone_pair_id():
	var lr := _flat_level(3, 1)
	lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
	var ls := LevelSystem.new()
	var errs := ls.validate(lr)
	assert_true(errs.any(func(e: String): return e.find("成对") >= 0))

func test_validate_rejects_triple_pair_id():
	var lr := _flat_level(4, 1)
	lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
	lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
	lr.mechanics.append(_portal("P1", Vector2i(3, 0)))
	var ls := LevelSystem.new()
	var errs := ls.validate(lr)
	assert_true(errs.any(func(e: String): return e.find("成对") >= 0))

func test_validate_rejects_empty_pair_id():
	var lr := _flat_level(3, 1)
	lr.mechanics.append(_portal("", Vector2i(1, 0)))
	lr.mechanics.append(_portal("", Vector2i(2, 0)))
	var ls := LevelSystem.new()
	var errs := ls.validate(lr)
	assert_true(errs.any(func(e: String): return e.find("不能为空") >= 0))

func test_validate_rejects_same_coord_pair():
	var lr := _flat_level(3, 1)
	lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
	lr.mechanics.append(_portal("P1", Vector2i(1, 0)))
	var ls := LevelSystem.new()
	var errs := ls.validate(lr)
	assert_true(errs.any(func(e: String): return e.find("不能相同") >= 0))

func test_validate_rejects_start_as_portal():
	var lr := _flat_level(3, 1)
	lr.mechanics.append(_portal("P1", Vector2i(0, 0)))
	lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
	lr.start = Vector2i(0, 0)
	var ls := LevelSystem.new()
	var errs := ls.validate(lr)
	assert_true(errs.any(func(e: String): return e.find("起点") >= 0))

func test_validate_rejects_goal_as_portal():
	var lr := _flat_level(3, 1)
	lr.mechanics.append(_portal("P1", Vector2i(0, 0)))
	lr.mechanics.append(_portal("P1", Vector2i(2, 0)))
	lr.start = Vector2i(1, 0)
	lr.goal = Vector2i(2, 0)
	var ls := LevelSystem.new()
	var errs := ls.validate(lr)
	assert_true(errs.any(func(e: String): return e.find("终点") >= 0))
```

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 新测试 FAIL —— `validate` 未校验传送门、`pair_of` 未注入。

- [ ] **Step 3: 实现 load 注入** — Modify `scripts/level/level_system.gd`

在 `load` 函数中,找到现有 mechanics 遍历循环(以 `if m is LeverData:` 结尾那段)之后、`for e in validate(level):` 之前,插入:

```gdscript
	var portals_by_id: Dictionary = {}
	for m in level.mechanics:
		if m is PortalData:
			var pid: String = (m as PortalData).pair_id
			var arr: Array = portals_by_id.get(pid, [])
			arr.append(m.coord)
			portals_by_id[pid] = arr
	for id in portals_by_id:
		var coords: Array = portals_by_id[id]
		if coords.size() == 2 and coords[0] != coords[1]:
			mechanic_system.register_portal(coords[0], coords[1])
```

- [ ] **Step 4: 实现 validate 校验** — Modify `scripts/level/level_system.gd`

在 `validate` 函数中,现有 `for m in level.mechanics:` 校验循环之后、`return errors` 之前,插入:

```gdscript
	var portal_counts: Dictionary = {}
	var portal_coords: Dictionary = {}
	var portal_at: Dictionary = {}
	for m in level.mechanics:
		if m is PortalData:
			var pid := (m as PortalData).pair_id
			if pid == "":
				errors.append("PortalData.pair_id 不能为空")
			portal_counts[pid] = portal_counts.get(pid, 0) + 1
			var arr: Array = portal_coords.get(pid, [])
			arr.append(m.coord)
			portal_coords[pid] = arr
			portal_at[m.coord] = true
	for pid in portal_counts:
		if portal_counts[pid] != 2:
			errors.append("PortalData.pair_id '%s' 须恰好成对(出现 %d 次)" % [pid, portal_counts[pid]])
		elif portal_coords[pid][0] == portal_coords[pid][1]:
			errors.append("PortalData.pair_id '%s' 两端坐标不能相同" % pid)
	if portal_at.has(level.start):
		errors.append("起点不能是传送门")
	if level.goal != Vector2i(-1, -1) and portal_at.has(level.goal):
		errors.append("终点不能是传送门")
```

- [ ] **Step 5: 跑测试验证通过(绿)**

Run: 全部测试命令
Expected: 全部通过(新增 7 绿;回归绿)。

- [ ] **Step 6: Commit**

```bash
git add scripts/level/level_system.gd tests/level/test_level_system.gd
git commit -m "feat(level): LevelSystem 注入传送配对 + validate 五类校验(TDD)"
```

---

## Task 5: 顺手 M3 — 桥/动态水 path_state.move 端到端集成测试

**Files:**
- Modify: `tests/level/test_level_system.gd`(追加测试;实现已在批次1,测试锁定行为)

- [ ] **Step 1: 写测试(预期直接绿,因实现已存)** — 追加到 `tests/level/test_level_system.gd` 末尾

```gdscript
func test_bridge_crossable_after_stepping_lever():
	var lr := _flat_level(4, 1)
	var lever := LeverData.new()
	lever.coord = Vector2i(1, 0)
	lever.id = "L1"
	var bridge := BridgeData.new()
	bridge.coord = Vector2i(2, 0)
	bridge.lever_ids = ["L1"]
	lr.mechanics.append(lever)
	lr.mechanics.append(bridge)
	var ls := LevelSystem.new()
	ls.load(lr)
	assert_true(ls.path_state.move(Vector2i(1, 0)))
	assert_true(ls.path_state.move(Vector2i(2, 0)))

func test_dynamic_water_low_phase_passable_high_phase_blocked():
	var lr := _flat_level(3, 1)
	var dw := DynamicWaterData.new()
	dw.coord = Vector2i(2, 0)
	dw.period = 2
	lr.mechanics.append(dw)
	var ls := LevelSystem.new()
	ls.load(lr)
	ls.path_state.move(Vector2i(1, 0))
	assert_true(ls.path_state.move(Vector2i(2, 0)))

func test_dynamic_water_high_phase_blocks_first_step():
	var lr := _flat_level(2, 1)
	var dw := DynamicWaterData.new()
	dw.coord = Vector2i(1, 0)
	dw.period = 2
	lr.mechanics.append(dw)
	var ls := LevelSystem.new()
	ls.load(lr)
	assert_false(ls.path_state.move(Vector2i(1, 0)))
```

> 推演:`period=2` → `LOW ⟺ phase<1 ⟺ path.size()%2==0`。Task5 第一测:踏入 (2,0) 前 path=`[start,(1,0)]` size2 → phase0 → LOW → 可走。第三测:踏入 (1,0) 前 path=`[start]` size1 → phase1 → HIGH → 拒。

- [ ] **Step 2: 跑测试**

Run: 全部测试命令
Expected: 全部通过(实现已在批次1;若任一红,说明 move 与 can_pass 集成有 bug,需修——但这属回归,不应发生)。

- [ ] **Step 3: Commit**

```bash
git add tests/level/test_level_system.gd
git commit -m "test(level): 补桥/动态水 path_state.move 端到端集成测试(M3)"
```

---

## Task 6: 集成关卡 test_level_03(含传送)+ 加载/通关测试

**Files:**
- Create: `resources/levels/test_level_03.tres`
- Create: `tests/level/test_level_03_load.gd`

布局(3×2,6 格全覆盖哈密顿):`start(0,0)→(1,0)→X(2,0)⇒Y(2,1)→(1,1)→(0,1)`

- [ ] **Step 1: 写测试** — Create `tests/level/test_level_03_load.gd`

```gdscript
extends GutTest

const LEVEL_PATH := "res://resources/levels/test_level_03.tres"

func _load() -> LevelSystem:
	var lr := load(LEVEL_PATH) as LevelResource
	var ls := LevelSystem.new()
	ls.load(lr)
	return ls

func test_load_portal_pair_registered():
	var ls := _load()
	assert_eq(ls.mechanic_system.pair_of(Vector2i(2, 0)), Vector2i(2, 1))
	assert_eq(ls.mechanic_system.pair_of(Vector2i(2, 1)), Vector2i(2, 0))

func test_move_into_portal_appends_peer():
	var ls := _load()
	var ps := ls.path_state
	assert_true(ps.move(Vector2i(1, 0)))
	assert_true(ps.move(Vector2i(2, 0)))
	assert_eq(ps.path.size(), 4)
	assert_eq(ps.path[3], Vector2i(2, 1))

func test_portal_level_solvable_cover_all():
	var ls := _load()
	var ps := ls.path_state
	ps.move(Vector2i(1, 0))
	ps.move(Vector2i(2, 0))
	ps.move(Vector2i(1, 1))
	ps.move(Vector2i(0, 1))
	assert_true(ls.check_win())
```

- [ ] **Step 2: 创建关卡 .tres** — Create `resources/levels/test_level_03.tres`

```
[gd_resource type="Resource" script_class="LevelResource" format=3]

[ext_resource type="Script" path="res://scripts/mechanics/mechanic_data.gd" id="1_md"]
[ext_resource type="Script" path="res://scripts/mechanics/portal_data.gd" id="2_pd"]
[ext_resource type="Script" path="res://scripts/level/level_resource.gd" id="3_lr"]

[sub_resource type="Resource" id="Portal_X"]
script = ExtResource("2_pd")
pair_id = "P1"
coord = Vector2i(2, 0)

[sub_resource type="Resource" id="Portal_Y"]
script = ExtResource("2_pd")
pair_id = "P1"
coord = Vector2i(2, 1)

[resource]
script = ExtResource("3_lr")
size = Vector2i(3, 2)
tiles = [Array[int]([0, 0, 0]), Array[int]([0, 0, 0])]
mechanics = Array[ExtResource("1_md")]([SubResource("Portal_X"), SubResource("Portal_Y")])
start = Vector2i(0, 0)
goal = Vector2i(-1, -1)
```

- [ ] **Step 3: import(让 Godot 识别新 .tres 与 PortalData 引用)**

Run: `"$GODOT" --headless --path . --import`
Expected: 无错误。

- [ ] **Step 4: 跑测试验证通过(绿)**

Run: 全部测试命令
Expected: 全部通过(新增 3 绿)。

> 若报「无法加载 test_level_03.tres」:检查 .tres 缩进/字段;PortalData 的 class_name 已 import。

- [ ] **Step 5: Commit**

```bash
git add resources/levels/test_level_03.tres tests/level/test_level_03_load.gd
git commit -m "test(level): 测试关卡 03(传送)+ 加载/走传送/通关集成测试"
```

---

## Task 7: GridRenderer P3 表现(紫块 + 标号 + 配对连线)

**Files:**
- Modify: `scripts/ui/grid_renderer.gd`

表现层无节点依赖单测难写;`_cell_color` 对 PortalData 返回固定色可断言。本 Task 以单测 + 手动验证。

- [ ] **Step 1: 写测试** — Create `tests/ui/test_grid_renderer_color.gd`

```gdscript
extends GutTest

func test_cell_color_portal():
	var r := GridRenderer.new()
	var ms := MechanicSystem.new()
	var p := PortalData.new()
	p.coord = Vector2i(0, 0)
	ms.set_data(Vector2i(0, 0), p)
	r._mechanic_system = ms
	assert_eq(r._cell_color(Vector2i(0, 0), []), GridRenderer.COLOR_PORTAL)
```

> 注:`_cell_color` 与 `COLOR_PORTAL` 需为可访问(后者 const 公开;前者 GDScript 默认可调)。

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: FAIL —— `COLOR_PORTAL` 未定义。

- [ ] **Step 3: 实现表现** — Modify `scripts/ui/grid_renderer.gd`

3a. 在常量区(`COLOR_DWATER_HIGH` 之后)加:

```gdscript
const COLOR_PORTAL := Color(0.55, 0.35, 0.70)
```

3b. 在 `_cell_color` 中,`if data is DynamicWaterData:` 分支之后、`return COLOR_EMPTY` 之前,插入:

```gdscript
	if data is PortalData:
		return COLOR_PORTAL
```

3c. 在 `_draw` 末尾(`for c in _path_state.path:` 已扫叠加循环之后)追加连线与标号:

```gdscript
	var font := ThemeDB.get_default_theme().default_font
	for pair in _mechanic_system.portal_pairs():
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var ca := Vector2((a.x + 0.5) * cell_size, (a.y + 0.5) * cell_size)
		var cb := Vector2((b.x + 0.5) * cell_size, (b.y + 0.5) * cell_size)
		draw_line(ca, cb, COLOR_PORTAL, 2.0)
	for y in range(_grid_model.size.y):
		for x in range(_grid_model.size.x):
			var coord := Vector2i(x, y)
			var data: MechanicData = _mechanic_system.data_at(coord)
			if data is PortalData:
				var center := Vector2((x + 0.5) * cell_size - 6, (y + 0.5) * cell_size - 8)
				draw_string(font, center, (data as PortalData).pair_id.substr(0, 1), 0, -1, 16)
```

- [ ] **Step 4: 跑测试验证通过(绿)**

Run: 全部测试命令
Expected: 全部通过(新增 1 绿)。

- [ ] **Step 5: 手动验证(必需,表现层)**

Run: `"$GODOT" --path .`(编辑器 F5 跑 boot.tscn,或临时把 test_level_03 设为主场景)
Expected: 传送门显示为紫色块,两端有紫色连线,格内有 pair_id 首字符标号;踏入入口后小和尚被自动传送到出口端。
> 若无现成入口跑 test_level_03:在 `scenes/boot.tscn` 或临时脚本里 `LevelSystem.load(load("res://resources/levels/test_level_03.tres"))` 并 bind GridRenderer。手动验完恢复改动。

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/grid_renderer.gd tests/ui/test_grid_renderer_color.gd
git commit -m "feat(ui): GridRenderer 传送门紫块+标号+配对连线(P3)"
```

---

## Task 8: 全量回归 + merge main

- [ ] **Step 1: 全量 GUT 回归**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全部通过(原 38 + 新增 ≈18 = ≈56;无 fail)。

- [ ] **Step 2: 手动跑游戏验收**

Run: `"$GODOT" --path .`
Expected: 传送机制可见可玩——踏入口自动到出口、undo 撤两步、连线/标号清晰、test_level_03 可通关。

- [ ] **Step 3: 更新 memory**

更新 `C:\Users\Administrator\.claude\projects\F--workspace-2-monk\memory\monk-coding-status.md`:传送批次2 完成,merge main,测试数更新,下一步(技术债 M1/M2/M4/M5 或关卡设计工具)。

- [ ] **Step 4: merge main(本地)**

```bash
git checkout main
git merge --no-ff feat/portal-batch2
```

- [ ] **Step 5: 提示用户手动 push**

> git HTTPS 经代理 TLS 握手失败,push 由用户手动:`git push origin main`(及删除远程/本地分支视情况)。

---

## 验收对照(spec §8)

- [x] Task 1: PortalData can_pass=true、计入需扫(§4.5)
- [x] Task 2: move 踏入口自动追加配对端(决策 A);三层校验零改动
- [x] Task 3: undo 撤两步、正常格一格、连续传送正确(决策 A1);零额外状态
- [x] Task 1: MechanicSystem `_portal_pairs`/`pair_of`/`portal_pairs`
- [x] Task 4: 注入配对 + 五类校验(成对/非空/两端不同/起点禁/goal 禁 S2)
- [x] Task 7: GridRenderer 紫块+标号+连线(决策 P3)
- [x] Task 5/6/8: GUT 全绿(含 M3 move 端到端)+ 手动跑可玩
- [x] 全 Task: 状态确定性(path 纯函数,撤销零副作用)
