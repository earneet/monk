# 机制批次 1(机关 / 门 / 桥 / 动态水)实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在逻辑层落地机关 / 门 / 桥 / 动态水 4 个机制的 `can_pass` 规则、状态推导、需扫、数据校验,并给 GridRenderer 加占位表现。

**Architecture:** `can_pass` 改多态分派——`MechanicData` 基类提供虚方法,各机制 Data 子类 override,`MechanicSystem` 主循环恒为 3 行、不随机制增长。机关状态查询(`is_lever_pressed`)封装在 `MechanicSystem`;需扫格与轻量校验在 `LevelSystem`。传送不在本批次(需改 `PathState.move`,单独批次)。

**Tech Stack:** Godot 4.7(stable)/ 纯 GDScript / GUT 9.6.0(`addons/gut`)/ Forward+。

**Spec:** `docs/project/2026-07-09-mechanics-batch1-design.md`

---

## 运行约定

Godot 可执行(Windows,含空格路径,命令行须加引号):

```bash
GODOT="C:\Program Files\godot_engine\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64.exe"
```

**跑全部测试**(每实现一步后执行):

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**import**(新建含 `class_name` 的 `.gd` 后必先执行,否则新类型未注册、测试报错):

```bash
"$GODOT" --headless --path . --import
```

> 当前基线:16 个 GUT 测试全绿。本计划结束后应仍全绿 + 新增若干。

## 文件结构

**新建脚本**(`scripts/mechanics/`):
- `lever_data.gd` — 机关数据(`id`),默认可通行
- `door_data.gd` — 门数据(`lever_ids`),任一机关被踩即开
- `bridge_data.gd` — 桥数据(`lever_ids`),任一机关被踩即铺放
- `dynamic_water_data.gd` — 动态水数据(`period`),相位决定可通行

**新建测试**(`tests/mechanics/`):
- `test_lever_data.gd` / `test_door_data.gd` / `test_bridge_data.gd` / `test_dynamic_water_data.gd`

**修改脚本**:
- `scripts/mechanics/mechanic_data.gd` — 加虚方法 `can_pass` / `counts_for_need_cover`
- `scripts/mechanics/wall_data.gd` / `flowing_water_data.gd` — override 为永久障碍
- `scripts/mechanics/mechanic_system.gd` — `can_pass` 改多态 + 机关状态查询
- `scripts/level/level_system.gd` — 机关坐标注入 + `need_cover` 多态 + `validate` 校验
- `scripts/ui/grid_renderer.gd` — 4 机制占位色 + 状态高亮

**不改动**:`path_state.gd` / `grid_model.gd` / `level_resource.gd`(传送批次才动 PathState)。

---

## Task 0:建立分支

- [ ] **Step 1: 从 main 开新分支**

```bash
git checkout main
git pull --ff-only 2>/dev/null || true
git checkout -b feat/mechanics-batch1
```

---

## Task 1:多态地基(重构,回归保护)

**说明:** 本任务是**纯重构,不改行为**——没有新失败测试,安全网是现有 16 测试。目标:把 `MechanicSystem.can_pass` 从 `is` 类型链改成多态分派,`need_cover` 改走 `counts_for_need_cover`。改完现有测试必须仍全绿。

**Files:**
- Modify: `scripts/mechanics/mechanic_data.gd`
- Modify: `scripts/mechanics/wall_data.gd`
- Modify: `scripts/mechanics/flowing_water_data.gd`
- Modify: `scripts/mechanics/mechanic_system.gd:12-20`
- Modify: `scripts/level/level_system.gd:38-46`

- [ ] **Step 1: MechanicData 加虚方法**

写入 `scripts/mechanics/mechanic_data.gd`(整文件):

```gdscript
class_name MechanicData
extends Resource

@export var coord: Vector2i

func can_pass(_path: Array, _ms: MechanicSystem) -> bool:
    return true

func counts_for_need_cover() -> bool:
    return true
```

- [ ] **Step 2: WallData override 为永久障碍**

写入 `scripts/mechanics/wall_data.gd`(整文件):

```gdscript
class_name WallData
extends MechanicData

func can_pass(_path: Array, _ms: MechanicSystem) -> bool:
    return false

func counts_for_need_cover() -> bool:
    return false
```

- [ ] **Step 3: FlowingWaterData override 为永久障碍**

写入 `scripts/mechanics/flowing_water_data.gd`(整文件):

```gdscript
class_name FlowingWaterData
extends MechanicData

func can_pass(_path: Array, _ms: MechanicSystem) -> bool:
    return false

func counts_for_need_cover() -> bool:
    return false
```

- [ ] **Step 4: MechanicSystem.can_pass 改多态**

把 `scripts/mechanics/mechanic_system.gd` 的 `can_pass` 替换为:

```gdscript
func can_pass(coord: Vector2i, path: Array) -> bool:
    var data: MechanicData = data_at(coord)
    if data == null:
        return true
    return data.can_pass(path, self)
```

(其余 `set_data` / `data_at` 不变。`_lever_cells` / `register_lever` / `is_lever_pressed` 在 Task 2 加。)

- [ ] **Step 5: LevelSystem.need_cover 改多态**

把 `scripts/level/level_system.gd` 的 `need_cover` 替换为:

```gdscript
func need_cover() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(_level.size.y):
        for x in range(_level.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = mechanic_system.data_at(coord)
            if data == null or data.counts_for_need_cover():
                result.append(coord)
    return result
```

- [ ] **Step 6: import + 跑全部测试,确认仍 16 绿**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS,失败数 0(与重构前一致)。

- [ ] **Step 7: Commit**

```bash
git add scripts/mechanics/mechanic_data.gd scripts/mechanics/wall_data.gd scripts/mechanics/flowing_water_data.gd scripts/mechanics/mechanic_system.gd scripts/level/level_system.gd
git commit -m "refactor(mechanics): can_pass 改多态分派(回归绿)"
```

---

## Task 2:机关 LeverData

**Files:**
- Create: `scripts/mechanics/lever_data.gd`
- Modify: `scripts/mechanics/mechanic_system.gd`(加机关状态查询)
- Test: `tests/mechanics/test_lever_data.gd`

- [ ] **Step 1: 写失败测试**

写入 `tests/mechanics/test_lever_data.gd`:

```gdscript
extends GutTest

func _ms_with(coord: Vector2i, data: MechanicData) -> MechanicSystem:
    var ms := MechanicSystem.new()
    ms.set_data(coord, data)
    return ms

func test_lever_passable():
    var lever := LeverData.new()
    lever.id = "L1"
    var ms := _ms_with(Vector2i(0, 0), lever)
    assert_true(ms.can_pass(Vector2i(0, 0), []))

func test_lever_pressed_when_coord_in_path():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    assert_true(ms.is_lever_pressed(["L1"], [Vector2i(0, 0)]))

func test_lever_not_pressed_when_coord_absent():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    assert_false(ms.is_lever_pressed(["L1"], [Vector2i(1, 1)]))
```

- [ ] **Step 2: import + 跑测试,确认失败**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 3 个新测试 FAIL(`LeverData` 未定义 / `register_lever` / `is_lever_pressed` 不存在)。

- [ ] **Step 3: 实现 LeverData**

写入 `scripts/mechanics/lever_data.gd`:

```gdscript
class_name LeverData
extends MechanicData

@export var id: String
```

(`can_pass` 用基类默认 `true`,`counts_for_need_cover` 用基类默认 `true`。)

- [ ] **Step 4: MechanicSystem 加机关状态查询**

在 `scripts/mechanics/mechanic_system.gd` 顶部字段区加,并在文件末尾加方法。完整文件应为:

```gdscript
class_name MechanicSystem
extends Resource

var _data_at: Dictionary = {}  # Vector2i -> MechanicData
var _lever_cells: Dictionary = {}  # id(String) -> coord(Vector2i)

func set_data(coord: Vector2i, data: MechanicData) -> void:
    _data_at[coord] = data

func data_at(coord: Vector2i) -> MechanicData:
    return _data_at.get(coord)

func can_pass(coord: Vector2i, path: Array) -> bool:
    var data: MechanicData = data_at(coord)
    if data == null:
        return true
    return data.can_pass(path, self)

func register_lever(id: String, coord: Vector2i) -> void:
    _lever_cells[id] = coord

func is_lever_pressed(lever_ids: Array, path: Array) -> bool:
    for id in lever_ids:
        var c: Variant = _lever_cells.get(id)
        if c != null and c in path:
            return true
    return false
```

- [ ] **Step 5: import + 跑测试,确认通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS(含 3 个新机关测试)。

- [ ] **Step 6: Commit**

```bash
git add scripts/mechanics/lever_data.gd scripts/mechanics/mechanic_system.gd tests/mechanics/test_lever_data.gd
git commit -m "feat(mechanics): 机关 LeverData + is_lever_pressed(TDD)"
```

---

## Task 3:门 DoorData

**Files:**
- Create: `scripts/mechanics/door_data.gd`
- Test: `tests/mechanics/test_door_data.gd`

- [ ] **Step 1: 写失败测试**

写入 `tests/mechanics/test_door_data.gd`:

```gdscript
extends GutTest

func test_door_closed_when_lever_not_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), door)
    assert_false(ms.can_pass(Vector2i(2, 0), [Vector2i(1, 1)]))

func test_door_open_when_lever_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), door)
    assert_true(ms.can_pass(Vector2i(2, 0), [Vector2i(0, 0)]))

func test_door_or_semantics_any_lever_opens():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    ms.register_lever("L2", Vector2i(5, 5))
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1", "L2"]
    ms.set_data(Vector2i(2, 0), door)
    assert_true(ms.can_pass(Vector2i(2, 0), [Vector2i(5, 5)]))

func test_door_empty_lever_ids_always_closed():
    var ms := MechanicSystem.new()
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = []
    ms.set_data(Vector2i(2, 0), door)
    assert_false(ms.can_pass(Vector2i(2, 0), [Vector2i(0, 0), Vector2i(1, 0)]))
```

- [ ] **Step 2: import + 跑测试,确认失败**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 4 个新测试 FAIL(`DoorData` 未定义)。

- [ ] **Step 3: 实现 DoorData**

写入 `scripts/mechanics/door_data.gd`:

```gdscript
class_name DoorData
extends MechanicData

@export var lever_ids: Array[String] = []

func can_pass(path: Array, ms: MechanicSystem) -> bool:
    return ms.is_lever_pressed(lever_ids, path)
```

- [ ] **Step 4: import + 跑测试,确认通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS(含 4 个新门测试)。

- [ ] **Step 5: Commit**

```bash
git add scripts/mechanics/door_data.gd tests/mechanics/test_door_data.gd
git commit -m "feat(mechanics): 门 DoorData OR 语义(TDD)"
```

---

## Task 4:桥 BridgeData

**Files:**
- Create: `scripts/mechanics/bridge_data.gd`
- Test: `tests/mechanics/test_bridge_data.gd`

- [ ] **Step 1: 写失败测试**

写入 `tests/mechanics/test_bridge_data.gd`:

```gdscript
extends GutTest

func test_bridge_not_placed_when_lever_absent():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(2, 0)
    bridge.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), bridge)
    assert_false(ms.can_pass(Vector2i(2, 0), [Vector2i(1, 1)]))

func test_bridge_placed_when_lever_pressed():
    var ms := MechanicSystem.new()
    ms.register_lever("L1", Vector2i(0, 0))
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(2, 0)
    bridge.lever_ids = ["L1"]
    ms.set_data(Vector2i(2, 0), bridge)
    assert_true(ms.can_pass(Vector2i(2, 0), [Vector2i(0, 0)]))
```

- [ ] **Step 2: import + 跑测试,确认失败**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 2 个新测试 FAIL(`BridgeData` 未定义)。

- [ ] **Step 3: 实现 BridgeData**

写入 `scripts/mechanics/bridge_data.gd`:

```gdscript
class_name BridgeData
extends MechanicData

@export var lever_ids: Array[String] = []

func can_pass(path: Array, ms: MechanicSystem) -> bool:
    return ms.is_lever_pressed(lever_ids, path)
```

- [ ] **Step 4: import + 跑测试,确认通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS(含 2 个新桥测试)。

- [ ] **Step 5: Commit**

```bash
git add scripts/mechanics/bridge_data.gd tests/mechanics/test_bridge_data.gd
git commit -m "feat(mechanics): 桥 BridgeData 铺放(TDD)"
```

---

## Task 5:动态水 DynamicWaterData

**Files:**
- Create: `scripts/mechanics/dynamic_water_data.gd`
- Test: `tests/mechanics/test_dynamic_water_data.gd`

- [ ] **Step 1: 写失败测试**

写入 `tests/mechanics/test_dynamic_water_data.gd`:

```gdscript
extends GutTest

func _ms_with(coord: Vector2i, period: int) -> MechanicSystem:
    var ms := MechanicSystem.new()
    var dw := DynamicWaterData.new()
    dw.coord = coord
    dw.period = period
    ms.set_data(coord, dw)
    return ms

# period=2: LOW={0}, HIGH={1}
func test_period2_phases():
    var ms := _ms_with(Vector2i(0, 0), 2)
    assert_true(ms.can_pass(Vector2i(0, 0), []))                                              # len0 phase0 LOW
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9)]))                               # len1 phase1 HIGH
    assert_true(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8)]))                # len2 phase0 LOW

# period=4: LOW={0,1}, HIGH={2,3}
func test_period4_phases():
    var ms := _ms_with(Vector2i(0, 0), 4)
    assert_true(ms.can_pass(Vector2i(0, 0), []))                                              # len0 LOW
    assert_true(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9)]))                                # len1 LOW
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8)]))               # len2 HIGH
    assert_false(ms.can_pass(Vector2i(0, 0), [Vector2i(9, 9), Vector2i(9, 8), Vector2i(9, 7)]))  # len3 HIGH

func test_default_period_is_4():
    var dw := DynamicWaterData.new()
    assert_eq(dw.period, 4)
```

- [ ] **Step 2: import + 跑测试,确认失败**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 3 个新测试 FAIL(`DynamicWaterData` 未定义)。

- [ ] **Step 3: 实现 DynamicWaterData**

写入 `scripts/mechanics/dynamic_water_data.gd`:

```gdscript
class_name DynamicWaterData
extends MechanicData

@export var period: int = 4

func can_pass(path: Array, _ms: MechanicSystem) -> bool:
    var phase: int = path.size() % period
    return phase < (period + 1) / 2
```

> `(period + 1) / 2` 为 GDScript 整数除法,等价 `ceil(period/2)`,与机制规范 §4.7 一致(落 ≥ 涨)。

- [ ] **Step 4: import + 跑测试,确认通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS(含 3 个新动态水测试)。

- [ ] **Step 5: Commit**

```bash
git add scripts/mechanics/dynamic_water_data.gd tests/mechanics/test_dynamic_water_data.gd
git commit -m "feat(mechanics): 动态水 DynamicWaterData 相位公式(TDD)"
```

---

## Task 6:LevelSystem 集成(机关注入 + 需扫含机制 + 校验)

**Files:**
- Modify: `scripts/level/level_system.gd`
- Test: `tests/level/test_level_system.gd`(追加)

- [ ] **Step 1: 追加失败测试**

在 `tests/level/test_level_system.gd` **末尾**追加(保留现有 `_flat_level` 与 3 个测试):

```gdscript
func test_need_cover_includes_mechanism_cells():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    ls.load(lr)
    var nc := ls.need_cover()
    assert_true(nc.has(Vector2i(1, 0)))
    assert_true(nc.has(Vector2i(2, 0)))

func test_door_opens_after_stepping_lever():
    var lr := _flat_level(4, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_false(ls.path_state.move(Vector2i(2, 0)))   # 机关未踩,门关,跨格也不可达(非邻接)
    ls.path_state.move(Vector2i(1, 0))                 # 踩机关
    assert_true(ls.path_state.move(Vector2i(2, 0)))    # 门开,可入

func test_validate_rejects_period_lt_2():
    var lr := _flat_level(3, 1)
    var dw := DynamicWaterData.new()
    dw.coord = Vector2i(1, 0)
    dw.period = 1
    lr.mechanics.append(dw)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("period") >= 0))

func test_validate_rejects_empty_lever_ids():
    var lr := _flat_level(3, 1)
    var door := DoorData.new()
    door.coord = Vector2i(1, 0)
    door.lever_ids = []
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("lever_ids") >= 0))

func test_validate_rejects_unknown_lever_ref():
    var lr := _flat_level(3, 1)
    var door := DoorData.new()
    door.coord = Vector2i(1, 0)
    door.lever_ids = ["NOPE"]
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    var errs := ls.validate(lr)
    assert_true(errs.any(func(e: String): return e.find("NOPE") >= 0))

func test_validate_accepts_valid_level():
    var lr := _flat_level(3, 1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(2, 0)
    door.lever_ids = ["L1"]
    lr.mechanics.append(lever)
    lr.mechanics.append(door)
    var ls := LevelSystem.new()
    assert_eq(ls.validate(lr), [])
```

- [ ] **Step 2: import + 跑测试,确认失败**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 6 个新测试 FAIL(`validate` 不存在;`need_cover` 未含机制格;机关未注入致门不开)。

- [ ] **Step 3: 改 LevelSystem(load 注入机关 + validate)**

写入 `scripts/level/level_system.gd`(整文件):

```gdscript
class_name LevelSystem
extends Resource

var grid_model: GridModel
var mechanic_system: MechanicSystem
var path_state: PathState
var _level: LevelResource

func load(level: LevelResource) -> void:
    _level = level
    grid_model = GridModel.new()
    grid_model.size = level.size
    mechanic_system = MechanicSystem.new()
    for y in range(level.size.y):
        for x in range(level.size.x):
            var coord := Vector2i(x, y)
            var t: int = level.tiles[y][x]
            match t:
                LevelResource.TileType.WALL:
                    var d := WallData.new()
                    d.coord = coord
                    mechanic_system.set_data(coord, d)
                    grid_model.set_mechanic_data(coord, d)
                LevelResource.TileType.FLOWING_WATER:
                    var d := FlowingWaterData.new()
                    d.coord = coord
                    mechanic_system.set_data(coord, d)
                    grid_model.set_mechanic_data(coord, d)
                _:
                    pass
    for m in level.mechanics:
        mechanic_system.set_data(m.coord, m)
        grid_model.set_mechanic_data(m.coord, m)
        if m is LeverData:
            var lever := m as LeverData
            mechanic_system.register_lever(lever.id, lever.coord)
    for e in validate(level):
        push_error(e)
    path_state = PathState.new()
    path_state.setup(mechanic_system, grid_model, level.start)
    path_state.set_need_cover(need_cover())

func need_cover() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(_level.size.y):
        for x in range(_level.size.x):
            var coord := Vector2i(x, y)
            var data: MechanicData = mechanic_system.data_at(coord)
            if data == null or data.counts_for_need_cover():
                result.append(coord)
    return result

func check_win() -> bool:
    return path_state.is_covered() and _goal_satisfied()

func _goal_satisfied() -> bool:
    if _level.goal == Vector2i(-1, -1):
        return true
    return path_state.path[path_state.path.size() - 1] == _level.goal

func validate(level: LevelResource) -> Array[String]:
    var errors: Array[String] = []
    var known_lever_ids: Dictionary = {}
    for m in level.mechanics:
        if m is LeverData:
            known_lever_ids[(m as LeverData).id] = true
    for m in level.mechanics:
        if m is DynamicWaterData:
            var dw := m as DynamicWaterData
            if dw.period < 2:
                errors.append("DynamicWaterData.period 必须 >= 2 (当前 %d)" % dw.period)
        elif m is DoorData:
            _validate_lever_ids(errors, (m as DoorData).lever_ids, "DoorData", known_lever_ids)
        elif m is BridgeData:
            _validate_lever_ids(errors, (m as BridgeData).lever_ids, "BridgeData", known_lever_ids)
    return errors

func _validate_lever_ids(errors: Array[String], lever_ids: Array, owner: String, known: Dictionary) -> void:
    if lever_ids.is_empty():
        errors.append("%s.lever_ids 不能为空" % owner)
        return
    for id in lever_ids:
        if not known.has(id):
            errors.append("%s 引用了不存在的机关 id: %s" % [owner, id])
```

- [ ] **Step 4: import + 跑测试,确认通过**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS(含 6 个新集成 / 校验测试;原 3 个 LevelSystem 测试仍绿)。

- [ ] **Step 5: Commit**

```bash
git add scripts/level/level_system.gd tests/level/test_level_system.gd
git commit -m "feat(level): 机关注入 + 需扫含机制 + 轻量校验(TDD)"
```

---

## Task 7:GridRenderer 占位表现

**说明:** 表现层(测试约定 §6:UI 不强制单元测),靠手动验证。

**Files:**
- Modify: `scripts/ui/grid_renderer.gd`

- [ ] **Step 1: 改 GridRenderer 加 4 机制占位色 + 状态高亮**

写入 `scripts/ui/grid_renderer.gd`(整文件):

```gdscript
class_name GridRenderer
extends Node2D

@export var cell_size: int = 64
var _grid_model: GridModel
var _mechanic_system: MechanicSystem
var _path_state: PathState

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_LEVER := Color(0.95, 0.78, 0.20)
const COLOR_DOOR := Color(0.45, 0.30, 0.20)
const COLOR_BRIDGE := Color(0.55, 0.40, 0.25)
const COLOR_DWATER_LOW := Color(0.62, 0.78, 0.84)
const COLOR_DWATER_HIGH := Color(0.30, 0.45, 0.55)
const COLOR_SWEPT := Color(0.42, 0.42, 0.42, 0.45)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)

func bind(grid_model: GridModel, mechanic_system: MechanicSystem, path_state: PathState) -> void:
    _grid_model = grid_model
    _mechanic_system = mechanic_system
    _path_state = path_state
    _path_state.path_changed.connect(func(_p): queue_redraw())
    queue_redraw()

func _draw() -> void:
    if _grid_model == null:
        return
    for y in range(_grid_model.size.y):
        for x in range(_grid_model.size.x):
            var coord := Vector2i(x, y)
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            draw_rect(rect, _cell_color(coord, _path_state.path), true)
            draw_rect(rect, COLOR_GRID, false)
    for c in _path_state.path:
        draw_rect(Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size), COLOR_SWEPT, true)

func _cell_color(coord: Vector2i, path: Array) -> Color:
    var data: MechanicData = _mechanic_system.data_at(coord)
    if data is WallData:
        return COLOR_WALL
    if data is FlowingWaterData:
        return COLOR_WATER
    if data is LeverData:
        return COLOR_LEVER
    if data is DoorData:
        var open: bool = _mechanic_system.is_lever_pressed((data as DoorData).lever_ids, path)
        return COLOR_DOOR if open else COLOR_DOOR.darkened(0.35)
    if data is BridgeData:
        var placed: bool = _mechanic_system.is_lever_pressed((data as BridgeData).lever_ids, path)
        return COLOR_BRIDGE if placed else COLOR_BRIDGE.darkened(0.35)
    if data is DynamicWaterData:
        var dw := data as DynamicWaterData
        var phase: int = path.size() % dw.period
        var low: bool = phase < (dw.period + 1) / 2
        return COLOR_DWATER_LOW if low else COLOR_DWATER_HIGH
    return COLOR_EMPTY
```

- [ ] **Step 2: import + 跑测试,确认未破坏逻辑层**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS(表现层改动不影响逻辑层测试)。

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/grid_renderer.gd
git commit -m "feat(ui): GridRenderer 4 机制占位色 + 状态高亮"
```

---

## Task 8:集成验证(测试关卡 + 手动跑)

**Files:**
- Create: `resources/levels/test_level_02.tres`

- [ ] **Step 1: 构造含 4 机制的测试关卡(脚本生成)**

新机制 Data 是新建 `class_name`,编辑器尚未识别其 `.tres` 文本格式,用 GUT 临时脚本生成更可靠。先创建生成器 `tests/_gen_level_02.gd`(临时,用完即删):

```gdscript
extends GutTest

func test_gen_and_save_level_02():
    var lr := LevelResource.new()
    lr.size = Vector2i(5, 5)
    lr.tiles.clear()
    for y in range(5):
        var row: Array[int] = []
        for x in range(5):
            row.append(LevelResource.TileType.EMPTY)
        lr.tiles.append(row)
    lr.start = Vector2i(0, 0)
    lr.goal = Vector2i(-1, -1)
    var lever := LeverData.new()
    lever.coord = Vector2i(1, 0)
    lever.id = "L1"
    var door := DoorData.new()
    door.coord = Vector2i(3, 0)
    door.lever_ids = ["L1"]
    var bridge := BridgeData.new()
    bridge.coord = Vector2i(4, 2)
    bridge.lever_ids = ["L1"]
    var dw := DynamicWaterData.new()
    dw.coord = Vector2i(2, 4)
    dw.period = 4
    lr.mechanics = [lever, door, bridge, dw]
    var err := ResourceSaver.save(lr, "res://resources/levels/test_level_02.tres")
    assert_eq(err, OK)
```

- [ ] **Step 2: import + 跑生成测试**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 生成测试 PASS;`resources/levels/test_level_02.tres` 已写出。

- [ ] **Step 3: 删除临时生成器**

```bash
rm tests/_gen_level_02.gd
```

- [ ] **Step 4: 跑全套测试,确认全绿**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 全部 PASS。

- [ ] **Step 5: 手动跑游戏验证**

```bash
"$GODOT" --path .
```

把主场景切到载入 `test_level_02.tres`(或临时改 boot/level 入口),验证:
- 机关(金黄)、门(棕)、桥(木褐)、动态水(浅/深蓝)可见
- 踩机关(1,0)后,门(3,0)变亮(开)、桥(4,2)变实色(铺放)
- 动态水(2,4)随步数相位浅↔深变化
- 已扫格半透明灰覆盖

- [ ] **Step 6: Commit 测试关卡**

```bash
git add resources/levels/test_level_02.tres
git commit -m "feat(level): 测试关卡 02(机关+门+桥+动态水)"
```

---

## 完成准则

- [ ] 全部 GUT 测试绿(基线 16 + 新增约 20)
- [ ] `MechanicSystem.can_pass` / `need_cover` 多态、无 `is` 链
- [ ] 4 机制规则符合机制规范 §4.3-4.7(相位表、OR 语义、空 lever 处理)
- [ ] `LevelSystem.validate` 覆盖 period≥2 / lever_ids 非空 / lever 引用存在
- [ ] 未触碰 `path_state.gd`(留给传送批次)
- [ ] 手动跑游戏可见 4 机制占位表现

## 完成后

- 合并 `feat/mechanics-batch1` → `main`(本地)
- push 由用户手动(git HTTPS 经代理 TLS 失败,见 memory)
- 更新 memory:批次 1 完成,下一批传送 PortalData
