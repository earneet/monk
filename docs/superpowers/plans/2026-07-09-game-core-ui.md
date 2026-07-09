# 游戏核心 MVP(UI / 输入 / 场景)实现计划

> **For agentic workers:** 本 plan 让游戏**真正可玩**。UI / 输入 / 场景为节点层,难 GUT 单元测(测试约定 §6「UI 不强制」),采用「写代码 + 场景装配 + 手动验证」(跑游戏)。Steps 用 checkbox 跟踪。

**Goal:** 让游戏可玩 MVP——加载纯路径关卡,键盘 / 点击移动,渲染网格 / 玩家 / 已扫格,撤销 / 重置,覆盖全部可通行格 = 胜利。

**Architecture:** 表现层(UI 节点)+ 输入层(InputSystem)订阅逻辑层(PathState / LevelSystem),数据模型驱动 + 逻辑 / 表现分离(见 `docs/project/2026-07-08-system-architecture-design.md` §3/§4.5/§4.6/§9)。`LevelController` 装配逻辑层 + UI,连接信号。

**Tech Stack:** Godot 4.7 / GDScript(节点 + 场景;UI 用占位色块,美术见美术风格指南)

**Scope(MVP 可玩):**
- **纳入**:InputSystem(键盘 / 点击 → move_intent)、GridRenderer(渲染网格 / 障碍 / 已扫)、PlayerSprite(玩家位置)、HUD(撤销 / 重置 + 胜利提示)、LevelController(装配 + 信号连接 + 胜负)、level.tscn(场景)、boot.tscn 接入、test_level_01.tres(纯路径关卡)、手动验证
- **不纳入(后续)**:门 / 机关 / 传送 / 桥 / 动态水、美术资产(占位色块)、章节进度 / SaveSystem、关卡设计工具接入

**上游 spec:**
- `docs/project/2026-07-08-system-architecture-design.md`(§4.5 UI、§4.6 InputSystem、§5 数据流、§9 装配)
- `docs/project/2026-07-08-gdd-design.md`(§6 操作、§5 胜负)
- 逻辑层 MVP(已完成,分支 `game-core-logic`):GridModel / MechanicSystem / PathState / LevelSystem

---

## Global Constraints

- 逻辑 / 表现分离:UI 不持游戏状态,只订阅逻辑层信号渲染 + 发用户意图
- 路径为唯一状态源:UI 的渲染都从 `path_state.path` / `level_system` 派生
- 占位美术:色块(空地米白 / 假山深灰 / 流水青 / 已扫淡墨 / 玩家朱砂),美术资产后续
- 坐标 `Vector2i`;网格世界坐标 = `coord * cell_size`
- 每组件完成 → 手动验证(跑游戏);逻辑层 GUT 测试保持全绿(回归)

## File Structure

```
scripts/
  ui/
    input_system.gd          # InputSystem(键盘/点击 → move_intent)
    grid_renderer.gd         # GridRenderer(Node2D,渲染网格)
    player_sprite.gd         # PlayerSprite(Node2D,玩家位置)
    hud.gd                   # HUD(Control,撤销/重置 + 胜利)
  level/
    level_controller.gd      # LevelController(装配逻辑层 + UI + 信号)
scenes/
  level.tscn                 # 关卡场景(节点树装配)
  boot.tscn                  # 启动(改:接入 level.tscn)
resources/
  levels/test_level_01.tres  # 纯路径测试关卡
```

---

### Task 1: InputSystem

**Files:** Create `scripts/ui/input_system.gd`

**依据:** 架构 §4.6;GDD §6(键盘 / 点击双输入)

- [ ] **Step 1: 实现 InputSystem**

```gdscript
class_name InputSystem
extends Node

signal move_intent(coord: Vector2i)
signal undo_request()
signal reset_request()

@export var cell_size: int = 64

var _path_state: PathState
var _grid_model: GridModel

func bind(path_state: PathState, grid_model: GridModel) -> void:
    _path_state = path_state
    _grid_model = grid_model

func _unhandled_input(event: InputEvent) -> void:
    if _path_state == null or _grid_model == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        _handle_key(event.keycode)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_click(event.position)

func _handle_key(code: int) -> void:
    if code == KEY_Z:
        undo_request.emit()
        return
    if code == KEY_R:
        reset_request.emit()
        return
    var d: Vector2i = Vector2i.ZERO
    match code:
        KEY_LEFT, KEY_A: d = Vector2i(-1, 0)
        KEY_RIGHT, KEY_D: d = Vector2i(1, 0)
        KEY_UP, KEY_W: d = Vector2i(0, -1)
        KEY_DOWN, KEY_S: d = Vector2i(0, 1)
        _: return
    _emit_from_delta(d)

func _handle_click(world_pos: Vector2) -> void:
    var coord: Vector2i = Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))
    move_intent.emit(coord)

func _emit_from_delta(d: Vector2i) -> void:
    if _path_state.path.size() == 0:
        return
    var last: Vector2i = _path_state.path[_path_state.path.size() - 1]
    move_intent.emit(last + d)
```

> 点击用世界坐标(假设 GridRenderer 原点对齐,无 camera 偏移;MVP 无 camera)。

- [ ] **Step 2: commit**

```bash
git add scripts/ui/input_system.gd && git commit -m "feat(ui): InputSystem 键盘+点击双输入"
```

---

### Task 2: GridRenderer

**Files:** Create `scripts/ui/grid_renderer.gd`

**依据:** 架构 §4.5;美术指南占位配色

- [ ] **Step 1: 实现 GridRenderer**

```gdscript
class_name GridRenderer
extends Node2D

@export var cell_size: int = 64
var _grid_model: GridModel
var _mechanic_system: MechanicSystem
var _path_state: PathState

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)      # 宣纸白
const COLOR_WALL := Color(0.17, 0.17, 0.17)       # 浓墨
const COLOR_WATER := Color(0.35, 0.48, 0.54)      # 青淡彩
const COLOR_SWEPT := Color(0.42, 0.42, 0.42)      # 淡墨(已扫)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)  # 网格线

func bind(grid_model: GridModel, mechanic_system: MechanicSystem, path_state: PathState) -> void:
    _grid_model = grid_model
    _mechanic_system = mechanic_system
    _path_state = path_state
    _path_state.path_changed.connect(queue_redraw)
    queue_redraw()

func _draw() -> void:
    if _grid_model == null:
        return
    for y in range(_grid_model.size.y):
        for x in range(_grid_model.size.x):
            var coord := Vector2i(x, y)
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            draw_rect(rect, _cell_color(coord), true)
            draw_rect(rect, COLOR_GRID, false)
    for c in _path_state.path:
        draw_rect(Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size), COLOR_SWEPT, true)

func _cell_color(coord: Vector2i) -> Color:
    var data: MechanicData = _mechanic_system.data_at(coord)
    if data is WallData:
        return COLOR_WALL
    if data is FlowingWaterData:
        return COLOR_WATER
    return COLOR_EMPTY
```

- [ ] **Step 2: commit**

```bash
git add scripts/ui/grid_renderer.gd && git commit -m "feat(ui): GridRenderer 网格渲染(占位配色)"
```

---

### Task 3: PlayerSprite

**Files:** Create `scripts/ui/player_sprite.gd`

- [ ] **Step 1: 实现 PlayerSprite**

```gdscript
class_name PlayerSprite
extends Node2D

@export var cell_size: int = 64
var _path_state: PathState

const COLOR_PLAYER := Color(0.76, 0.27, 0.18)  # 朱砂红

func bind(path_state: PathState) -> void:
    _path_state = path_state
    _path_state.path_changed.connect(_update)
    _update()

func _update() -> void:
    if _path_state.path.size() > 0:
        var last: Vector2i = _path_state.path[_path_state.path.size() - 1]
        position = (last * cell_size) + Vector2i(cell_size / 2, cell_size / 2)
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, cell_size * 0.3, COLOR_PLAYER)
```

- [ ] **Step 2: commit**

```bash
git add scripts/ui/player_sprite.gd && git commit -m "feat(ui): PlayerSprite 玩家位置"
```

---

### Task 4: HUD

**Files:** Create `scripts/ui/hud.gd`

- [ ] **Step 1: 实现 HUD(代码创建按钮 + 胜利标签)**

```gdscript
class_name HUD
extends Control

signal undo_pressed()
signal reset_pressed()

var _win_label: Label

func _ready() -> void:
    var undo := Button.new()
    undo.text = "撤销(Z)"
    undo.position = Vector2(10, 10)
    undo.pressed.connect(func(): undo_pressed.emit())
    add_child(undo)

    var reset := Button.new()
    reset.text = "重置(R)"
    reset.position = Vector2(110, 10)
    reset.pressed.connect(func(): reset_pressed.emit())
    add_child(reset)

    _win_label = Label.new()
    _win_label.text = ""
    _win_label.position = Vector2(10, 50)
    _win_label.add_theme_font_size_override("font_size", 24)
    add_child(_win_label)

func show_win() -> void:
    _win_label.text = "✦ 通关!✦"

func clear_win() -> void:
    _win_label.text = ""
```

- [ ] **Step 2: commit**

```bash
git add scripts/ui/hud.gd && git commit -m "feat(ui): HUD 撤销/重置 + 胜利提示"
```

---

### Task 5: LevelController

**Files:** Create `scripts/level/level_controller.gd`

**依据:** 架构 §5 数据流;装配逻辑层 + UI

- [ ] **Step 1: 实现 LevelController(装配 + 信号连接 + 胜负)**

```gdscript
class_name LevelController
extends Node

@export var level: LevelResource
@export var cell_size: int = 64

@onready var _input_system: InputSystem = $InputSystem
@onready var _grid_renderer: GridRenderer = $GridRenderer
@onready var _player_sprite: PlayerSprite = $PlayerSprite
@onready var _hud: HUD = $HUD

var _level_system: LevelSystem
var _path_state: PathState
var _grid_model: GridModel
var _mechanic_system: MechanicSystem

func _ready() -> void:
    _level_system = LevelSystem.new()
    _level_system.load(level)
    _path_state = _level_system.path_state
    _grid_model = _level_system.grid_model
    _mechanic_system = _level_system.mechanic_system

    _input_system.cell_size = cell_size
    _input_system.bind(_path_state, _grid_model)
    _grid_renderer.cell_size = cell_size
    _grid_renderer.bind(_grid_model, _mechanic_system, _path_state)
    _player_sprite.cell_size = cell_size
    _player_sprite.bind(_path_state)

    _input_system.move_intent.connect(_on_move_intent)
    _input_system.undo_request.connect(_on_undo)
    _input_system.reset_request.connect(_on_reset)
    _hud.undo_pressed.connect(_on_undo)
    _hud.reset_pressed.connect(_on_reset)
    _path_state.path_changed.connect(_check_win)

func _on_move_intent(coord: Vector2i) -> void:
    _path_state.move(coord)
    _hud.clear_win()

func _on_undo() -> void:
    _path_state.undo()
    _hud.clear_win()

func _on_reset() -> void:
    _level_system.load(level)
    _path_state = _level_system.path_state
    _rebind()
    _hud.clear_win()

func _rebind() -> void:
    _input_system.bind(_path_state, _grid_model)
    _grid_renderer.bind(_grid_model, _mechanic_system, _path_state)
    _player_sprite.bind(_path_state)

func _check_win(_p: Array) -> void:
    if _level_system.check_win():
        _hud.show_win()
```

- [ ] **Step 2: commit**

```bash
git add scripts/level/level_controller.gd && git commit -m "feat(level): LevelController 装配 + 信号连接 + 胜负"
```

---

### Task 6: level.tscn(场景装配)

**Files:** Create `scenes/level.tscn`

- [ ] **Step 1: 写场景文件**

```
[gd_scene load_steps=6 format=3 uid="uid://b000level0001"]

[ext_resource type="Resource" path="res://resources/levels/test_level_01.tres" id="1_lvl"]
[ext_resource type="Script" path="res://scripts/level/level_controller.gd" id="2_ctrl"]
[ext_resource type="Script" path="res://scripts/ui/input_system.gd" id="3_inp"]
[ext_resource type="Script" path="res://scripts/ui/grid_renderer.gd" id="4_grid"]
[ext_resource type="Script" path="res://scripts/ui/player_sprite.gd" id="5_plr"]
[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="6_hud"]

[node name="Level" type="Node"]
script = ExtResource("2_ctrl")
level = ExtResource("1_lvl")
cell_size = 64

[node name="GridRenderer" type="Node2D" parent="."]
script = ExtResource("4_grid")

[node name="PlayerSprite" type="Node2D" parent="."]
script = ExtResource("5_plr")

[node name="InputSystem" type="Node" parent="."]
script = ExtResource("3_inp")

[node name="HUD" type="Control" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("6_hud")
```

> uid 会在 Godot 打开时重生成;若报错可删 uid 行让 Godot 重指。

- [ ] **Step 2: commit**

```bash
git add scenes/level.tscn && git commit -m "feat(scene): level.tscn 场景装配"
```

---

### Task 7: test_level_01.tres(纯路径测试关卡)

**Files:** Create `resources/levels/test_level_01.tres`

- [ ] **Step 1: 写关卡(简单纯路径:5×5,几个假山,起点 (0,0),无终点)**

```
[gd_resource type="Resource" script_class="LevelResource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/level/level_resource.gd" id="1"]

[resource]
script = ExtResource("1")
size = Vector2i(5, 5)
tiles = [[0,0,0,0,0],[0,1,0,1,0],[0,0,1,0,0],[0,1,0,0,0],[0,0,0,0,0]]
start = Vector2i(0, 0)
goal = Vector2i(-1, -1)
mechanics = []
```

> tiles 用 TileType 值:0=EMPTY,1=WALL,2=FLOWING_WATER。此关 5×5,散布假山,可走哈密顿路径。

- [ ] **Step 2: commit**

```bash
git add resources/levels/test_level_01.tres && git commit -m "feat(level): test_level_01 纯路径测试关卡"
```

---

### Task 8: boot.tscn 接入

**Files:** Modify `scenes/boot.tscn`(或 project.godot main_scene 改 level.tscn)

- [ ] **Step 1: 改 project.godot 主场景为 level.tscn(最简)**

在 `project.godot` 的 `[application]` 改 `run/main_scene` 指向 level.tscn(或保留 boot,boot 跳 level)。最简:直接改 main_scene。

- [ ] **Step 2: commit**

```bash
git add project.godot && git commit -m "feat: 主场景接入 level.tscn"
```

---

### Task 9: 手动验证

- [ ] **Step 1: 运行游戏**

```bash
godot --path .   # 编辑器 F5 或命令行(需窗口,非 headless)
```

- [ ] **Step 2: 验证清单**
- [ ] 网格渲染(5×5,假山深灰、空地米白)
- [ ] 玩家(朱砂圆)在 (0,0)
- [ ] 方向键/WASD 移动;点击相邻格移动
- [ ] 已扫格变淡墨
- [ ] 撞墙 / 重复 / 非相邻 → 不动
- [ ] Z / 撤销按钮 → 回退一步(状态正确回滚)
- [ ] R / 重置按钮 → 清空回起点
- [ ] 覆盖全部可通行格 → 「✦ 通关!✦」
- [ ] 逻辑层 GUT 测试仍全绿(回归):`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

- [ ] **Step 3: final commit(若手动验证有调整)**

---

## Self-Review

- **Spec 覆盖**:架构 §4.5 UI、§4.6 InputSystem、§5 数据流、§9 装配 ✓;GDD §6 操作、§5 胜负 ✓;逻辑层 MVP 复用 ✓
- **占位符**:uid 标注(Godot 重生);关卡 tiles 注释;无功能 TBD
- **类型一致**:`move_intent(coord: Vector2i)`、`path_changed`、`cell_size`、`bind(...)` 贯穿;坐标 `Vector2i`
- **缺口**:InputSystem 点击假设无 camera(MVP);HUD 代码建按钮(非 .tscn);胜负无 UI 庆祝动画(MVP 标签);reset 重 load(简单)

## Execution Handoff

计划保存到 `docs/superpowers/plans/2026-07-09-game-core-ui.md`。**Inline 执行**(本会话编码,你手动验证跑游戏)。逻辑层 GUT 测试保持绿作回归。

**注意**:UI / 场景需 Godot 编辑器或带窗口运行验证(headless 跑不了游戏);逻辑层测试仍用 headless GUT。
