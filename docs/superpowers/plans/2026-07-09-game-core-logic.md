# 游戏核心 MVP(逻辑层)实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 严格 TDD:每步先写失败测试 → 跑失败 → 实现 → 跑通过 → commit。

**Goal:** 实现游戏核心的**逻辑层 MVP**——数据 + GridModel + MechanicSystem(仅障碍)+ PathState + LevelSystem,纯 GDScript、可被 GUT 独立测试,验证「移动 / 不重复 / 撤销 / 覆盖 = 胜利」核心循环的规则逻辑。

**Architecture:** 数据模型驱动 + 逻辑 / 表现分离(见 `docs/project/2026-07-08-system-architecture-design.md`)。逻辑层四模块 + 数据 Resource 均为纯 GDScript,无节点依赖。机制仅含障碍(假山 `WallData` / 流水 `FlowingWaterData`);门 / 机关 / 传送 / 桥 / 动态水留后续增量。

**Tech Stack:** Godot 4.7 / 纯 GDScript / GUT(`addons/gut`)

**Scope(MVP 逻辑层):**
- **纳入**:TileType + LevelResource、MechanicData 基类 + WallData/FlowingWaterData、GridModel、MechanicSystem(障碍 can_pass)、PathState(move/undo/不重复/确定性/path_changed)、LevelSystem(load/build/check_win/需扫格推导)
- **不纳入(后续 plan)**:门 / 机关 / 传送 / 桥 / 动态水机制、UI(GridRenderer/PlayerSprite/HUD)、InputSystem、场景装配、关卡设计工具、章节进度、美术资产

**上游 spec:**
- `docs/project/2026-07-08-system-architecture-design.md`(§4 模块 API、§9 确定性)
- `docs/project/2026-07-09-level-data-format-design.md`(§3/§4/§5 Resource 字段、§10 加载流程)
- `docs/project/2026-07-09-mechanics-spec-design.md`(§3 总则、§4.1/§4.2 障碍、§5 需扫格)
- `docs/project/2026-07-09-testing-convention-design.md`(GUT、目录、TDD)

---

## Global Constraints

- 编码 UTF-8、行尾 LF;缩进 4 空格;命名 snake_case / PascalCase / UPPER_SNAKE;私有 `_` 前缀;`class_name` 暴露类型(CLAUDE.md)
- 默认不加注释,仅在解释「为什么」时加
- 坐标统一 `Vector2i`
- 每任务 TDD:写测试 → 跑失败 → 实现 → 跑通过 → commit
- GUT 已安装(`addons/gut`);测试目录 `tests/<子系统>/`,镜像 `scripts/`
- 运行测试(命令行):`godot --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`

## File Structure

```
scripts/
  grid/
    grid_model.gd              # GridModel(网格 + 邻接 + mechanic_data_at)
    path_state.gd              # PathState(路径 = 唯一状态源;move/undo/is_covered)
  mechanics/
    mechanic_data.gd           # MechanicData 基类(coord)
    wall_data.gd               # WallData(假山)
    flowing_water_data.gd      # FlowingWaterData(流水)
    mechanic_system.gd         # MechanicSystem(can_pass;类型→规则映射)
  level/
    level_resource.gd          # LevelResource + TileType 枚举
    level_system.gd            # LevelSystem(load/build/check_win)
tests/
  grid/test_grid_model.gd
  grid/test_path_state.gd
  mechanics/test_mechanic_system.gd
  level/test_level_system.gd
```

---

### Task 1: 数据层(LevelResource + TileType + MechanicData + WallData/FlowingWaterData)

**Files:** Create `scripts/level/level_resource.gd`、`scripts/mechanics/mechanic_data.gd`、`scripts/mechanics/wall_data.gd`、`scripts/mechanics/flowing_water_data.gd`

**依据:** 数据格式 §3/§4/§5;机制规范 §4.1/§4.2

- [ ] **Step 1: 写数据类(无独立测试,由后续模块测试覆盖)**

`scripts/level/level_resource.gd`:
```gdscript
class_name LevelResource
extends Resource

enum TileType { EMPTY, WALL, FLOWING_WATER }

@export var size: Vector2i
@export var tiles: Array[Array[int]]
@export var mechanics: Array[MechanicData]
@export var start: Vector2i
@export var goal: Vector2i = Vector2i(-1, -1)
@export var meta: LevelMeta
```

`scripts/mechanics/mechanic_data.gd`:
```gdscript
class_name MechanicData
extends Resource

@export var coord: Vector2i
```

`scripts/mechanics/wall_data.gd`:
```gdscript
class_name WallData
extends MechanicData
```

`scripts/mechanics/flowing_water_data.gd`:
```gdscript
class_name FlowingWaterData
extends MechanicData
```

> `LevelMeta` 若未定义,先建最小 `scripts/level/level_meta.gd`(`id`/`display_name`/`difficulty`)。

- [ ] **Step 2: commit**

```bash
git add scripts/ && git commit -m "feat: 数据层 LevelResource + MechanicData 基类 + 障碍 Data"
```

---

### Task 2: GridModel(TDD)

**Files:** Create `scripts/grid/grid_model.gd`、`tests/grid/test_grid_model.gd`

**依据:** 架构 §4.1;数据格式 §10(由 tiles/mechanics 构建)

- [ ] **Step 1: 写失败测试**

`tests/grid/test_grid_model.gd`:
```gdscript
extends GutTest

func test_neighbors_four_directions():
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    var n := gm.neighbors(Vector2i(1, 1))
    assert_eq(n.size(), 4)
    assert_true(n.has(Vector2i(0, 1)))
    assert_true(n.has(Vector2i(2, 1)))
    assert_true(n.has(Vector2i(1, 0)))
    assert_true(n.has(Vector2i(1, 2)))

func test_neighbors_at_corner_excludes_out_of_bounds():
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    var n := gm.neighbors(Vector2i(0, 0))
    assert_eq(n.size(), 2)  # 仅 (1,0) 与 (0,1)

func test_in_bounds():
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    assert_true(gm.in_bounds(Vector2i(2, 2)))
    assert_false(gm.in_bounds(Vector2i(3, 0)))
    assert_false(gm.in_bounds(Vector2i(-1, 0)))
```

- [ ] **Step 2: 跑测试,确认失败(GridModel 未定义)**

- [ ] **Step 3: 实现 GridModel**

`scripts/grid/grid_model.gd`:
```gdscript
class_name GridModel
extends Resource

var size: Vector2i
var _mechanic_at: Dictionary  # Vector2i -> MechanicData

func in_bounds(coord: Vector2i) -> bool:
    return coord.x >= 0 and coord.y >= 0 and coord.x < size.x and coord.y < size.y

func neighbors(coord: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var c := coord + d
        if in_bounds(c):
            result.append(c)
    return result

func set_mechanic_data(coord: Vector2i, data: MechanicData) -> void:
    _mechanic_at[coord] = data

func mechanic_data_at(coord: Vector2i) -> MechanicData:
    return _mechanic_at.get(coord)
```

- [ ] **Step 4: 跑测试,确认通过**

- [ ] **Step 5: commit**

```bash
git add scripts/grid/ tests/grid/ && git commit -m "feat: GridModel 网格 + 四向邻接"
```

---

### Task 3: MechanicSystem(TDD,障碍规则)

**Files:** Create `scripts/mechanics/mechanic_system.gd`、`tests/mechanics/test_mechanic_system.gd`

**依据:** 架构 §4.2;机制规范 §3.2(can_pass 查机制通行性)、§4.1/§4.2(假山/流水恒不可通行)、§4.4(空地?空地无 MechanicData,默认可通行)

- [ ] **Step 1: 写失败测试**

`tests/mechanics/test_mechanic_system.gd`:
```gdscript
extends GutTest

func _ms_with(coord: Vector2i, data: MechanicData) -> MechanicSystem:
    var ms := MechanicSystem.new()
    ms.set_data(coord, data)
    return ms

func test_wall_not_passable():
    var ms := _ms_with(Vector2i(0, 0), WallData.new())
    assert_false(ms.can_pass(Vector2i(0, 0), []))

func test_flowing_water_not_passable():
    var ms := _ms_with(Vector2i(0, 0), FlowingWaterData.new())
    assert_false(ms.can_pass(Vector2i(0, 0), []))

func test_empty_passable():
    var ms := MechanicSystem.new()  # 无机制 = 空地
    assert_true(ms.can_pass(Vector2i(0, 0), []))
```

- [ ] **Step 2: 跑测试,确认失败**

- [ ] **Step 3: 实现 MechanicSystem(MVP:障碍规则 + 数据驱动框架雏形)**

`scripts/mechanics/mechanic_system.gd`:
```gdscript
class_name MechanicSystem
extends Resource

var _data_at: Dictionary  # Vector2i -> MechanicData

func set_data(coord: Vector2i, data: MechanicData) -> void:
    _data_at[coord] = data

func data_at(coord: Vector2i) -> MechanicData:
    return _data_at.get(coord)

func can_pass(coord: Vector2i, _path: Array) -> bool:
    var data := data_at(coord)
    if data == null:
        return true  # 空地
    if data is WallData:
        return false
    if data is FlowingWaterData:
        return false
    return true
```

> 后续增量(门/桥/传送/动态水)在此分派,保持 `can_pass(coord, path)` 签名(path 为入参,确定性)。

- [ ] **Step 4: 跑测试,确认通过**

- [ ] **Step 5: commit**

```bash
git add scripts/mechanics/mechanic_system.gd tests/mechanics/ && git commit -m "feat: MechanicSystem 障碍 can_pass(数据驱动框架)"
```

---

### Task 4: PathState(TDD)

**Files:** Create `scripts/grid/path_state.gd`、`tests/grid/test_path_state.gd`

**依据:** 架构 §4.3;机制规范 §3.3(move 三层校验)、§3.4(确定性);GDD §4

- [ ] **Step 1: 写失败测试**

`tests/grid/test_path_state.gd`:
```gdscript
extends GutTest

func _ps(ms: MechanicSystem, gm: GridModel) -> PathState:
    var ps := PathState.new()
    ps.setup(ms, gm, Vector2i(0, 0))
    return ps

func _gm3() -> GridModel:
    var gm := GridModel.new()
    gm.size = Vector2i(3, 3)
    return gm

func test_move_valid_appends():
    var ps := _ps(MechanicSystem.new(), _gm3())
    assert_true(ps.move(Vector2i(1, 0)))
    assert_eq(ps.path.size(), 2)

func test_move_out_of_non_adjacent_fails():
    var ps := _ps(MechanicSystem.new(), _gm3())
    assert_false(ps.move(Vector2i(2, 2)))  # 非正交相邻
    assert_eq(ps.path.size(), 1)

func test_move_repeat_fails():
    var ps := _ps(MechanicSystem.new(), _gm3())
    ps.move(Vector2i(1, 0))
    assert_false(ps.move(Vector2i(0, 0)))  # 起点已扫,不可重复
    assert_eq(ps.path.size(), 2)

func test_move_into_wall_fails():
    var ms := MechanicSystem.new()
    ms.set_data(Vector2i(1, 0), WallData.new())
    var ps := _ps(ms, _gm3())
    assert_false(ps.move(Vector2i(1, 0)))

func test_undo_rolls_back():
    var ps := _ps(MechanicSystem.new(), _gm3())
    ps.move(Vector2i(1, 0))
    ps.undo()
    assert_eq(ps.path.size(), 1)
    assert_eq(ps.path[0], Vector2i(0, 0))

func test_is_covered():
    var gm := GridModel.new()
    gm.size = Vector2i(1, 2)  # 仅两格,均空地
    var ps := _ps(MechanicSystem.new(), gm)
    assert_false(ps.is_covered())
    ps.move(Vector2i(0, 1))
    assert_true(ps.is_covered())  # 覆盖两格

func test_path_changed_signal():
    var ps := _ps(MechanicSystem.new(), _gm3())
    var received: Array = []
    ps.path_changed.connect(func(p: Array): received.append(p.duplicate())
    ps.move(Vector2i(1, 0))
    assert_eq(received.size(), 1)
```

- [ ] **Step 2: 跑测试,确认失败**

- [ ] **Step 3: 实现 PathState**

`scripts/grid/path_state.gd`:
```gdscript
class_name PathState
extends Resource

var path: Array[Vector2i]
var _ms: MechanicSystem
var _gm: GridModel

signal path_changed(new_path: Array)

func setup(ms: MechanicSystem, gm: GridModel, start: Vector2i) -> void:
    _ms = ms
    _gm = gm
    path = [start]
    _emit()

func move(coord: Vector2i) -> bool:
    if not _gm.in_bounds(coord):
        return false
    if coord in path:
        return false
    if path.size() > 0:
        var last: Vector2i = path[-1]
        if coord not in _gm.neighbors(last):
            return false
    if not _ms.can_pass(coord, path):
        return false
    path.append(coord)
    _emit()
    return true

func undo() -> void:
    if path.size() > 1:
        path.pop_back()
        _emit()

func is_covered() -> bool:
    # MVP:覆盖全部非障碍格。需扫格集合由 LevelSystem 计算并注入(见 Task 5)
    # 这里先用占位:由 _need_cover 注入
    for c in _need_cover:
        if c not in path:
            return false
    return true

var _need_cover: Array[Vector2i] = []
func set_need_cover(cells: Array[Vector2i]) -> void:
    _need_cover = cells

func _emit() -> void:
    path_changed.emit(path.duplicate())
```

> `is_covered` 依赖「需扫格集合」(LevelSystem 推导,机制规范 §5 / 数据格式 §9),通过 `set_need_cover` 注入,保持 PathState 不依赖 LevelSystem。

- [ ] **Step 4: 跑测试,确认通过**

- [ ] **Step 5: commit**

```bash
git add scripts/grid/path_state.gd tests/grid/test_path_state.gd && git commit -m "feat: PathState 路径唯一状态源 + move/undo/确定性"
```

---

### Task 5: LevelSystem(TDD)

**Files:** Create `scripts/level/level_system.gd`、`tests/level/test_level_system.gd`

**依据:** 架构 §4.4;数据格式 §10(加载流程);机制规范 §5(需扫格 = 非永久障碍)

- [ ] **Step 1: 写失败测试**

`tests/level/test_level_system.gd`:
```gdscript
extends GutTest

func _flat_level(w: int, h: int) -> LevelResource:
    var lr := LevelResource.new()
    lr.size = Vector2i(w, h)
    lr.tiles.clear()
    for y in range(h):
        var row: Array[int] = []
        for x in range(w):
            row.append(LevelResource.TileType.EMPTY)
        lr.tiles.append(row)
    lr.start = Vector2i(0, 0)
    lr.goal = Vector2i(-1, -1)
    return lr

func test_build_flat_grid():
    var ls := LevelSystem.new()
    ls.load(_flat_level(2, 2))
    assert_not_null(ls.grid_model)
    assert_eq(ls.grid_model.size, Vector2i(2, 2))

func test_need_cover_excludes_walls():
    var lr := _flat_level(3, 1)
    lr.tiles[0][1] = LevelResource.TileType.WALL  # (1,0) 假山
    var ls := LevelSystem.new()
    ls.load(lr)
    var nc := ls.need_cover()
    assert_false(nc.has(Vector2i(1, 0)))  # 假山不计
    assert_true(nc.has(Vector2i(0, 0)))
    assert_true(nc.has(Vector2i(2, 0)))

func test_check_win_when_covered():
    var lr := _flat_level(2, 1)  # 两格空地
    var ls := LevelSystem.new()
    ls.load(lr)
    ls.path_state.set_need_cover(ls.need_cover())
    assert_false(ls.check_win())
    ls.path_state.move(Vector2i(1, 0))
    assert_true(ls.check_win())
```

- [ ] **Step 2: 跑测试,确认失败**

- [ ] **Step 3: 实现 LevelSystem**

`scripts/level/level_system.gd`:
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
                    var d := WallData.new(); d.coord = coord
                    mechanic_system.set_data(coord, d)
                    grid_model.set_mechanic_data(coord, d)
                LevelResource.TileType.FLOWING_WATER:
                    var d := FlowingWaterData.new(); d.coord = coord
                    mechanic_system.set_data(coord, d)
                    grid_model.set_mechanic_data(coord, d)
                _:
                    pass
    for m in level.mechanics:
        mechanic_system.set_data(m.coord, m)
        grid_model.set_mechanic_data(m.coord, m)
    path_state = PathState.new()
    path_state.setup(mechanic_system, grid_model, level.start)
    path_state.set_need_cover(need_cover())

func need_cover() -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for y in range(_level.size.y):
        for x in range(_level.size.x):
            var coord := Vector2i(x, y)
            var data := mechanic_system.data_at(coord)
            if data == null:  # 空地(非永久障碍)
                result.append(coord)
            # 机制格(门/机关/…)同样计入,MVP 仅障碍,故 data 非空即障碍,不计
    return result

func check_win() -> bool:
    return path_state.is_covered() and _goal_satisfied()

func _goal_satisfied() -> bool:
    if _level.goal == Vector2i(-1, -1):
        return true  # 不限终点
    return path_state.path[-1] == _level.goal
```

- [ ] **Step 4: 跑测试,确认通过**

- [ ] **Step 5: 跑全部测试,确认全绿**

```bash
godot --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

- [ ] **Step 6: commit**

```bash
git add scripts/level/level_system.gd tests/level/ && git commit -m "feat: LevelSystem 加载 + 需扫格推导 + 胜负判定

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec 覆盖**:架构 §4.1-§4.4(GridModel/MechanicSystem/PathState/LevelSystem)✓;数据格式 §3/§4/§5/§10 ✓;机制规范 §3/§4.1/§4.2/§5 ✓;测试约定 §4/§5(GUT 目录 + 场景)✓
- **占位符**:无 TBD;未纳入项(门/机关/传送/桥/动态水、UI/输入/场景)明确标注「后续 plan」
- **类型一致**:`can_pass(coord, path)`、`mechanic_data_at(coord)`、`path_changed`、`need_cover` 等命名贯穿一致;坐标统一 `Vector2i`
- **缺口**:LevelMeta 需最小定义(Task 1 备注);PathState.is_covered 用 set_need_cover 注入解耦(合理);MVP 未含终点测试(goal 校验留 _goal_satisfied,Task 5 可补一个 has_goal 用例)

## Execution Handoff

计划已保存到 `docs/superpowers/plans/2026-07-09-game-core-logic.md`。两种执行方式:

1. **Subagent-Driven(推荐)**:每 Task 派新 subagent,任务间复核,快速迭代
2. **Inline Execution**:本会话用 executing-plans,批量执行 + 检查点

**注意**:本计划为**纯文档计划产物**(实现指引);执行(写代码 / 跑 GUT 测试)需要 Godot 环境——测试由你在 Godot 编辑器或命令行运行验证。哪种执行方式?
