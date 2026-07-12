# 关卡设计工具 MVP(路径优先法最小闭环)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现路径优先法关卡设计工具的最小闭环——@tool EditorPlugin + 主视图(逐格点击画路径)+ 智能填充 + 导出 LevelResource + 基础校验,产出游戏可直接加载的关卡。

**Architecture:** 纯逻辑层(`WorkLevelResource` 模型 / `PathValidator` 校验 / `Filler` 填充 / `Exporter` 导出)独立可测,GUT 严格 TDD;表现层(EditorPlugin + 主视图 + 画布)是薄交互层,手动验证。路径优先法保证可解(路径外全填障碍,路径即覆盖全部可通行格)。

**Tech Stack:** Godot 4.7 stable / 纯 GDScript / GUT 9.7.0 / Forward+ / @tool EditorPlugin

---

## 前置约定(所有 Task 通用)

- **分支**: `feat/level-tool-mvp`(自 main 13477b7,执行时建)。全程在此分支。
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
- **TDD**: 每 Task 先写失败测试 → 跑(红)→ 最小实现 → 跑(绿)→ commit。跑测试用「跑全部」命令(新测试 fail 即红、全 pass 即绿,自带回归保护)。
- **GDScript 风格**: 4 空格缩进;snake_case;默认不加注释(除非解释「为什么」)。
- **现状基线**: 68 GUT 测试绿(main 13477b7)。`LevelResource` 字段 = `size/tiles(Array,每行 Array[int])/mechanics:Array[MechanicData]/start/goal(-1,-1)/meta:LevelMeta`;`LevelResource.TileType {EMPTY=0, WALL=1, FLOWING_WATER=2}`;`LevelMeta{id,display_name,difficulty}`。

---

## 文件结构

| 文件 | 职责 | 创建/修改 |
|---|---|---|
| `scripts/tool/work_level_resource.gd` | 工作模型(spec §4 字段) | Create |
| `scripts/tool/path_validator.gd` | `validate(path, size) -> Array[String]` | Create |
| `scripts/tool/filler.gd` | `fill(wlr) -> Array`(tiles 矩阵) | Create |
| `scripts/tool/exporter.gd` | `export_level(wlr) -> LevelResource` | Create |
| `tests/tool/test_path_validator.gd` | PathValidator 单测 | Create |
| `tests/tool/test_filler.gd` | Filler 单测 | Create |
| `tests/tool/test_exporter.gd` | Exporter 单测 | Create |
| `tests/tool/test_export_integration.gd` | 导出→load+通关集成 | Create |
| `addons/level_designer/plugin.cfg` | 插件元信息 | Create |
| `addons/level_designer/plugin.gd` | EditorPlugin(注册主视图) | Create |
| `addons/level_designer/main_view.gd` | 主视图(UI 容器 + 导出) | Create |
| `addons/level_designer/level_canvas.gd` | 画布(_draw + 点击画路径) | Create |

---

## Task 1: WorkLevelResource 工作模型

**Files:**
- Create: `scripts/tool/work_level_resource.gd`

- [ ] **Step 1: 创建模型** — Create `scripts/tool/work_level_resource.gd`

```gdscript
class_name WorkLevelResource
extends Resource

enum FillRule { BORDER_WALL_INNER_WATER }

@export var meta: LevelMeta
@export var chapter_id: String
@export var size: Vector2i
@export var path: Array[Vector2i] = []
@export var has_goal: bool = false
@export var mechanics: Array[MechanicData] = []
@export var fill_rule: FillRule = FillRule.BORDER_WALL_INNER_WATER
@export var obstacle_overrides: Dictionary = {}
@export var notes: String
@export var version: int = 1
```

> `mechanics`/`obstacle_overrides` 首批留空占位,前向兼容 spec §4(决策 D4)。`FillRule` enum 首批只一项,留扩展位。

- [ ] **Step 2: import(新增 class_name)**

Run: `"$GODOT" --headless --path . --import`
Expected: 无错误退出。

- [ ] **Step 3: 跑全部测试(回归确认,模型无单测)**

Run: 全部测试命令
Expected: 68 全绿(模型新增不影响现有)。

- [ ] **Step 4: Commit**

```bash
git add scripts/tool/work_level_resource.gd
git commit -m "feat(tool): WorkLevelResource 工作模型(spec §4 字段)"
```

---

## Task 2: PathValidator(正交邻接/不重复/在界内)

**Files:**
- Create: `tests/tool/test_path_validator.gd`
- Create: `scripts/tool/path_validator.gd`

- [ ] **Step 1: 写失败测试** — Create `tests/tool/test_path_validator.gd`

```gdscript
extends GutTest

func test_empty_path_valid():
    var p: Array[Vector2i] = []
    assert_eq(PathValidator.validate(p, Vector2i(3, 3)), [])

func test_single_cell_valid():
    var p: Array[Vector2i] = [Vector2i(0, 0)]
    assert_eq(PathValidator.validate(p, Vector2i(3, 3)), [])

func test_adjacent_path_valid():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    assert_eq(PathValidator.validate(p, Vector2i(3, 1)), [])

func test_diagonal_rejected():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
    var errs := PathValidator.validate(p, Vector2i(3, 3))
    assert_true(errs.any(func(e: String): return e.find("邻接") >= 0))

func test_duplicate_rejected():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 0)]
    var errs := PathValidator.validate(p, Vector2i(3, 3))
    assert_true(errs.any(func(e: String): return e.find("重复") >= 0))

func test_out_of_bounds_rejected():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 5)]
    var errs := PathValidator.validate(p, Vector2i(3, 3))
    assert_true(errs.any(func(e: String): return e.find("越出") >= 0))
```

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 6 个新测试 FAIL —— `PathValidator` 未定义。

- [ ] **Step 3: 实现 PathValidator** — Create `scripts/tool/path_validator.gd`

```gdscript
class_name PathValidator

static func validate(path: Array[Vector2i], size: Vector2i) -> Array[String]:
    var errors: Array[String] = []
    var seen: Dictionary = {}
    for i in range(path.size()):
        var c: Vector2i = path[i]
        if c.x < 0 or c.x >= size.x or c.y < 0 or c.y >= size.y:
            errors.append("路径格 (%d,%d) 越出网格 %s" % [c.x, c.y, size])
        if seen.has(c):
            errors.append("路径格 (%d,%d) 重复" % [c.x, c.y])
        seen[c] = true
        if i > 0:
            var prev: Vector2i = path[i - 1]
            if abs(c.x - prev.x) + abs(c.y - prev.y) != 1:
                errors.append("路径格 (%d,%d) 与前一格 (%d,%d) 非正交邻接" % [c.x, c.y, prev.x, prev.y])
    return errors
```

- [ ] **Step 4: import + 跑测试验证通过(绿)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 全绿(原 68 + 新增 6 = 74)。

- [ ] **Step 5: Commit**

```bash
git add scripts/tool/path_validator.gd tests/tool/test_path_validator.gd
git commit -m "feat(tool): PathValidator 正交邻接/不重复/在界内校验(TDD)"
```

---

## Task 3: Filler(BORDER_WALL_INNER_WATER 智能填充)

**Files:**
- Create: `tests/tool/test_filler.gd`
- Create: `scripts/tool/filler.gd`

填充规则:路径格 = EMPTY;路径外格——从网格边界 flood fill(四向正交,不穿过路径格)能到达的 = 外部 → WALL;其余路径外格(被路径包围)= 内部 → FLOWING_WATER。`obstacle_overrides` 优先(首批为空,逻辑保留)。

- [ ] **Step 1: 写失败测试** — Create `tests/tool/test_filler.gd`

```gdscript
extends GutTest

func _wlr(size: Vector2i, path: Array[Vector2i]) -> WorkLevelResource:
    var w := WorkLevelResource.new()
    w.size = size
    w.path = path
    return w

func test_path_cells_empty():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var tiles := Filler.fill(_wlr(Vector2i(3, 1), p))
    assert_eq(tiles.size(), 1)
    assert_eq(tiles[0].size(), 3)
    for x in range(3):
        assert_eq(tiles[0][x], LevelResource.TileType.EMPTY)

func test_border_non_path_filled_wall():
    var p: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
    var tiles := Filler.fill(_wlr(Vector2i(3, 3), p))
    assert_eq(tiles[0][0], LevelResource.TileType.WALL)
    assert_eq(tiles[2][2], LevelResource.TileType.WALL)
    assert_eq(tiles[1][1], LevelResource.TileType.EMPTY)

func test_inner_enclosed_filled_water():
    var p: Array[Vector2i] = [
        Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
        Vector2i(2, 1),
        Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2),
        Vector2i(0, 1)
    ]
    var tiles := Filler.fill(_wlr(Vector2i(3, 3), p))
    assert_eq(tiles[1][1], LevelResource.TileType.FLOWING_WATER)
```

> `test_inner_enclosed_filled_water`:3×3 path 绕外圈一圈(8 格邻接合法),中心 (1,1) 被 path 四面包围,flood fill 到不了 → 内部 → FLOWING_WATER。

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 3 个新测试 FAIL —— `Filler` 未定义。

- [ ] **Step 3: 实现 Filler** — Create `scripts/tool/filler.gd`

```gdscript
class_name Filler

static func fill(wlr: WorkLevelResource) -> Array:
    var path_set: Dictionary = {}
    for c in wlr.path:
        path_set[c] = true
    var border: Dictionary = _flood_border(wlr.size, path_set)
    var tiles: Array = []
    for y in range(wlr.size.y):
        var row: Array[int] = []
        for x in range(wlr.size.x):
            var coord := Vector2i(x, y)
            var t: int = LevelResource.TileType.EMPTY
            if not path_set.has(coord):
                if wlr.obstacle_overrides.has(coord):
                    t = _override_tile(wlr.obstacle_overrides[coord])
                elif border.has(coord):
                    t = LevelResource.TileType.WALL
                else:
                    t = LevelResource.TileType.FLOWING_WATER
            row.append(t)
        tiles.append(row)
    return tiles

static func _flood_border(size: Vector2i, path_set: Dictionary) -> Dictionary:
    var border: Dictionary = {}
    var queue: Array[Vector2i] = []
    for x in range(size.x):
        _enqueue(Vector2i(x, 0), size, path_set, border, queue)
        _enqueue(Vector2i(x, size.y - 1), size, path_set, border, queue)
    for y in range(size.y):
        _enqueue(Vector2i(0, y), size, path_set, border, queue)
        _enqueue(Vector2i(size.x - 1, y), size, path_set, border, queue)
    while queue.size() > 0:
        var c: Vector2i = queue.pop_front()
        _enqueue(c + Vector2i(1, 0), size, path_set, border, queue)
        _enqueue(c + Vector2i(-1, 0), size, path_set, border, queue)
        _enqueue(c + Vector2i(0, 1), size, path_set, border, queue)
        _enqueue(c + Vector2i(0, -1), size, path_set, border, queue)
    return border

static func _enqueue(coord: Vector2i, size: Vector2i, path_set: Dictionary, border: Dictionary, queue: Array[Vector2i]) -> void:
    if coord.x < 0 or coord.x >= size.x or coord.y < 0 or coord.y >= size.y:
        return
    if path_set.has(coord) or border.has(coord):
        return
    border[coord] = true
    queue.append(coord)

static func _override_tile(value: Variant) -> int:
    if value == "WALL":
        return LevelResource.TileType.WALL
    if value == "FLOWING_WATER":
        return LevelResource.TileType.FLOWING_WATER
    return LevelResource.TileType.EMPTY
```

- [ ] **Step 4: import + 跑测试验证通过(绿)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 全绿(74 + 新增 3 = 77)。

- [ ] **Step 5: Commit**

```bash
git add scripts/tool/filler.gd tests/tool/test_filler.gd
git commit -m "feat(tool): Filler BORDER_WALL_INNER_WATER 智能填充(flood fill,TDD)"
```

---

## Task 4: Exporter(WorkLevel → LevelResource)

**Files:**
- Create: `tests/tool/test_exporter.gd`
- Create: `scripts/tool/exporter.gd`

映射:`size` 直传;`tiles` = Filler.fill;`mechanics` 直传(首批空);`start` = path[0] 或 (-1,-1);`goal` = has_goal? path[-1] : (-1,-1);`meta` 直传。

- [ ] **Step 1: 写失败测试** — Create `tests/tool/test_exporter.gd`

```gdscript
extends GutTest

func _wlr(size: Vector2i, path: Array[Vector2i], has_goal: bool) -> WorkLevelResource:
    var w := WorkLevelResource.new()
    w.size = size
    w.path = path
    w.has_goal = has_goal
    w.meta = LevelMeta.new()
    w.meta.id = "T1"
    w.meta.display_name = "Test"
    w.meta.difficulty = 1
    return w

func test_export_maps_fields_no_goal():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var lr := Exporter.export_level(_wlr(Vector2i(3, 1), p, false))
    assert_eq(lr.size, Vector2i(3, 1))
    assert_eq(lr.start, Vector2i(0, 0))
    assert_eq(lr.goal, Vector2i(-1, -1))
    assert_eq(lr.tiles.size(), 1)
    assert_eq(lr.tiles[0][0], LevelResource.TileType.EMPTY)
    assert_eq(lr.meta.id, "T1")

func test_export_goal_when_has_goal():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
    var lr := Exporter.export_level(_wlr(Vector2i(2, 1), p, true))
    assert_eq(lr.goal, Vector2i(1, 0))

func test_export_border_filled_wall():
    var p: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
    var lr := Exporter.export_level(_wlr(Vector2i(3, 3), p, false))
    assert_eq(lr.tiles[0][0], LevelResource.TileType.WALL)
    assert_eq(lr.tiles[1][1], LevelResource.TileType.EMPTY)
```

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 3 个新测试 FAIL —— `Exporter` 未定义。

- [ ] **Step 3: 实现 Exporter** — Create `scripts/tool/exporter.gd`

```gdscript
class_name Exporter

static func export_level(wlr: WorkLevelResource) -> LevelResource:
    var lr := LevelResource.new()
    lr.size = wlr.size
    lr.tiles = Filler.fill(wlr)
    lr.mechanics = wlr.mechanics
    if wlr.path.size() > 0:
        lr.start = wlr.path[0]
        lr.goal = wlr.path[wlr.path.size() - 1] if wlr.has_goal else Vector2i(-1, -1)
    else:
        lr.start = Vector2i(-1, -1)
        lr.goal = Vector2i(-1, -1)
    lr.meta = wlr.meta
    return lr
```

- [ ] **Step 4: import + 跑测试验证通过(绿)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 全绿(77 + 新增 3 = 80)。

- [ ] **Step 5: Commit**

```bash
git add scripts/tool/exporter.gd tests/tool/test_exporter.gd
git commit -m "feat(tool): Exporter WorkLevel→LevelResource 全字段映射(TDD)"
```

---

## Task 5: 集成测试(导出 → LevelSystem.load + 通关)

**Files:**
- Create: `tests/tool/test_export_integration.gd`

实现已在 Task 3/4,本 Task 锁定端到端:导出的 LevelResource 能被 `LevelSystem.load` 加载并可通关。

- [ ] **Step 1: 写测试** — Create `tests/tool/test_export_integration.gd`

```gdscript
extends GutTest

func test_exported_level_loadable_and_winnable():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = p
    w.has_goal = false
    var lr := Exporter.export_level(w)
    var ls := LevelSystem.new()
    ls.load(lr)
    assert_not_null(ls.grid_model)
    ls.path_state.move(Vector2i(1, 0))
    ls.path_state.move(Vector2i(2, 0))
    assert_true(ls.check_win())

func test_exported_level_with_mechanism_free():
    var p: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = p
    w.has_goal = true
    var lr := Exporter.export_level(w)
    assert_eq(lr.goal, Vector2i(2, 0))
    assert_eq(lr.mechanics.size(), 0)
```

> 第一测:3×1 全 path → 导出 → load → 走完 3 格 → `check_win`(覆盖全部 EMPTY 格 + goal=(-1,-1) 视为满足)。

- [ ] **Step 2: 跑测试验证通过(绿,实现已存)**

Run: 全部测试命令
Expected: 全绿(80 + 新增 2 = 82)。

- [ ] **Step 3: Commit**

```bash
git add tests/tool/test_export_integration.gd
git commit -m "test(tool): 导出→LevelSystem.load+通关集成测试"
```

---

## Task 6: EditorPlugin + 主视图(手动验证)

**Files:**
- Create: `addons/level_designer/plugin.cfg`
- Create: `addons/level_designer/plugin.gd`
- Create: `addons/level_designer/main_view.gd`
- Create: `addons/level_designer/level_canvas.gd`

表现层无单测,手动验证。拆 `main_view`(UI 容器+导出)与 `level_canvas`(画布 _draw + 点击)——因 Control 绘制须 override `_draw()` 虚方法(非 signal),画布须独立类。

- [ ] **Step 1: 创建插件元信息** — Create `addons/level_designer/plugin.cfg`

```ini
[plugin]
name="LevelDesigner"
description="monk 路径优先法关卡设计工具"
author="monk"
version="0.1.0"
script="plugin.gd"
```

- [ ] **Step 2: 创建 EditorPlugin** — Create `addons/level_designer/plugin.gd`

```gdscript
@tool
extends EditorPlugin

var main_view: Control

func _enter_tree() -> void:
    main_view = LevelDesignerMainView.new()
    EditorInterface.get_editor_main_screen().add_child(main_view)
    _make_visible(false)

func _exit_tree() -> void:
    if main_view:
        main_view.queue_free()
        main_view = null

func _has_main_screen() -> bool:
    return true

func _make_visible(visible: bool) -> void:
    if main_view:
        main_view.visible = visible

func _get_plugin_name() -> String:
    return "LevelDesigner"

func _get_plugin_icon() -> Texture2D:
    return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
```

- [ ] **Step 3: 创建主视图** — Create `addons/level_designer/main_view.gd`

```gdscript
@tool
class_name LevelDesignerMainView
extends Control

var work: WorkLevelResource
var canvas: LevelCanvas
var size_x_spin: SpinBox
var size_y_spin: SpinBox
var goal_check: CheckBox

func _ready() -> void:
    if work == null:
        work = _new_work()
    _build_ui()

func _new_work() -> WorkLevelResource:
    var w := WorkLevelResource.new()
    w.size = Vector2i(5, 5)
    w.path = []
    w.meta = LevelMeta.new()
    w.meta.id = "new_level"
    w.meta.display_name = "New Level"
    w.meta.difficulty = 1
    return w

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(vbox)
    var toolbar := HBoxContainer.new()
    vbox.add_child(toolbar)
    var lx := Label.new()
    lx.text = "宽"
    toolbar.add_child(lx)
    size_x_spin = SpinBox.new()
    size_x_spin.min_value = 1
    size_x_spin.max_value = 30
    size_x_spin.value = work.size.x
    size_x_spin.value_changed.connect(_on_size_changed)
    toolbar.add_child(size_x_spin)
    var ly := Label.new()
    ly.text = "高"
    toolbar.add_child(ly)
    size_y_spin = SpinBox.new()
    size_y_spin.min_value = 1
    size_y_spin.max_value = 30
    size_y_spin.value = work.size.y
    size_y_spin.value_changed.connect(_on_size_changed)
    toolbar.add_child(size_y_spin)
    goal_check = CheckBox.new()
    goal_check.text = "末格为终点"
    goal_check.button_pressed = work.has_goal
    goal_check.toggled.connect(func(p: bool):
        work.has_goal = p
        canvas.queue_redraw())
    toolbar.add_child(goal_check)
    var clear_btn := Button.new()
    clear_btn.text = "清空路径"
    clear_btn.pressed.connect(func():
        work.path = []
        canvas.queue_redraw())
    toolbar.add_child(clear_btn)
    var export_btn := Button.new()
    export_btn.text = "导出 .tres"
    export_btn.pressed.connect(_on_export)
    toolbar.add_child(export_btn)
    canvas = LevelCanvas.new()
    canvas.work = work
    canvas.cell_size = 48
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    vbox.add_child(canvas)

func _on_size_changed(_v: float) -> void:
    work.size = Vector2i(int(size_x_spin.value), int(size_y_spin.value))
    var kept: Array[Vector2i] = []
    for c in work.path:
        if c.x < work.size.x and c.y < work.size.y:
            kept.append(c)
    work.path = kept
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    canvas.queue_redraw()

func _on_export() -> void:
    var errs := PathValidator.validate(work.path, work.size)
    if errs.size() > 0:
        print("[LevelDesigner] 路径无效,不导出: ", errs)
        return
    var lr := Exporter.export_level(work)
    var path := "res://resources/levels/%s.tres" % work.meta.id
    var err := ResourceSaver.save(lr, path)
    if err == OK:
        print("[LevelDesigner] 已导出: ", path)
    else:
        print("[LevelDesigner] 导出失败: ", err)
```

- [ ] **Step 4: 创建画布** — Create `addons/level_designer/level_canvas.gd`

```gdscript
@tool
class_name LevelCanvas
extends Control

var work: WorkLevelResource
var cell_size: int = 48

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_PATH := Color(0.95, 0.78, 0.20, 0.65)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)

func _draw() -> void:
    if work == null:
        return
    var tiles := Filler.fill(work)
    for y in range(work.size.y):
        for x in range(work.size.x):
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            var t: int = tiles[y][x]
            var color: Color = COLOR_EMPTY
            if t == LevelResource.TileType.WALL:
                color = COLOR_WALL
            elif t == LevelResource.TileType.FLOWING_WATER:
                color = COLOR_WATER
            draw_rect(rect, color, true)
            draw_rect(rect, COLOR_GRID, false)
    for c in work.path:
        var rect := Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size)
        draw_rect(rect, COLOR_PATH, true)

func _gui_input(event: InputEvent) -> void:
    if work == null:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var coord := Vector2i(int(event.position.x / cell_size), int(event.position.y / cell_size))
        if coord.x < 0 or coord.x >= work.size.x or coord.y < 0 or coord.y >= work.size.y:
            return
        if coord in work.path:
            return
        if work.path.size() > 0:
            var last: Vector2i = work.path[work.path.size() - 1]
            if abs(coord.x - last.x) + abs(coord.y - last.y) != 1:
                return
        work.path.append(coord)
        queue_redraw()
```

- [ ] **Step 5: import + 跑全部测试(确认无破坏)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 82 全绿(EditorPlugin 代码不参与 GUT,但确认 import 无错、无回归)。

- [ ] **Step 6: 手动验证(必需,表现层)**

1. 打开 Godot 编辑器(`"$GODOT" --path .`)→ 项目 → 项目设置 → 插件 → 启用 "LevelDesigner"。
2. 编辑器顶部出现 "LevelDesigner" 主视图按钮,点击进入。
3. 调整宽/高(如 5×5),左键逐格点击画一条覆盖全部格的哈密顿路径(实时高亮 + 路径外自动 WALL/FLOWING_WATER 预览)。
4. 点 "导出 .tres",控制台输出 `[LevelDesigner] 已导出: res://resources/levels/new_level.tres`。
5. 运行游戏(F5),临时让 boot 或测试脚本 `LevelSystem.load(load("res://resources/levels/new_level.tres"))`,确认能加载、走完路径通关。
> 手动验完无需恢复改动(导出的 .tres 是产物,可保留或删)。

- [ ] **Step 7: Commit**

```bash
git add addons/level_designer/
git commit -m "feat(tool): EditorPlugin + 主视图 + 画布(左键画路径/智能填充预览/导出 .tres)"
```

---

## Task 7: 全量回归 + merge main

- [ ] **Step 1: 全量 GUT 回归**

Run: 全部测试命令
Expected: 全绿(82;无 fail)。

- [ ] **Step 2: 更新 memory**

更新 `monk-coding-status.md`:关卡设计工具 MVP(路径闭环)完成,测试数更新,下一步(机制标注 + 顺序校验 / 拖拽 / 自动生成)。

- [ ] **Step 3: merge main(本地)**

```bash
git checkout main
git merge --no-ff feat/level-tool-mvp
git branch -d feat/level-tool-mvp
```

- [ ] **Step 4: 提示用户手动 push**

> git HTTPS 经代理 TLS 握手失败,push 由用户手动:`git push origin main`。

---

## 验收对照(spec §8)

- [x] Task 1: `WorkLevelResource` 含 `path`(LevelResource 没有)
- [x] Task 2: PathValidator 正交邻接/不重复/在界内
- [x] Task 3: Filler BORDER_WALL_INNER_WATER(边界 WALL + 内部 FLOWING_WATER)
- [x] Task 4: Exporter 全字段映射(path→tiles/start/goal/mechanics/meta)
- [x] Task 5: 导出 .tres → LevelSystem.load + 通关(集成)
- [x] Task 6: EditorPlugin 主视图画路径 + 智能填充预览 + 导出 .tres(手动)
- [x] 路径优先闭环完整:画 → 填 → 校验 → 导出
- [x] 纯逻辑 GUT 全绿(68 → 82)

## 自审(writing-plans §Self-Review)

1. **Spec coverage**:spec §1 范围 → Task1-6 全覆盖;§4 模块 → 文件结构表一一对应;§6 任务切片 → Task1-6;§8 验收 → 验收对照。无遗漏。
2. **Placeholder scan**:无 TBD/TODO/"适当处理";每步含完整代码或确切命令。
3. **Type consistency**:`PathValidator.validate(path, size) -> Array[String]`、`Filler.fill(wlr) -> Array`、`Exporter.export_level(wlr) -> LevelResource`、`WorkLevelResource.{size,path,has_goal,mechanics,meta,obstacle_overrides,fill_rule}` 前后一致;`LevelResource.TileType.EMPTY/WALL/FLOWING_WATER` 与现状 `level_resource.gd` 一致。
