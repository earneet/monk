# 关卡设计工具增量(机制标注 + 顺序校验)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在关卡设计工具 MVP 上增加路径上标注 5 种机制(门/机关/传送/桥/动态水)+ 路径顺序校验(机关先于门/桥、传送 A→B 相邻、动态水 LOW),让工具能设计含机制的关卡并保证按设计 path 可通关。

**Architecture:** 新增纯逻辑 `MechanicOrderValidator`(GUT 可测,校验路径顺序约束——运行时 validate 查不到的工具独特价值);表现层 `LevelCanvas`/`MainView` 扩展机制模式工具栏 + 点击标注 + 机制渲染;`Exporter` 不改(mechanics 直传);数据完整性复用运行时 `LevelSystem.validate`(DRY)。

**Tech Stack:** Godot 4.7 stable / 纯 GDScript / GUT 9.7.0 / Forward+ / @tool EditorPlugin

---

## 前置约定(所有 Task 通用)

- **分支**: `feat/level-tool-mechanics`(自 main,执行时建)。全程在此分支。
- **Godot 可执行**: `GODOT="C:/Program Files/godot_engine/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64.exe"`
- **跑全部 GUT 测试**: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- **改/加 `class_name` 后先 import**: `"$GODOT" --headless --path . --import`
- **TDD**: 每 Task 先写失败测试 → 跑(红)→ 最小实现 → 跑(绿)→ commit。
- **GDScript 风格**: 4 空格缩进;snake_case;默认不加注释。
- **现状基线**: 82 GUT 测试绿(main)。MVP 模块:`scripts/tool/{work_level_resource,path_validator,filler,exporter}.gd` + `addons/level_designer/{plugin,main_view,level_canvas}.gd`。`WorkLevelResource.mechanics: Array[MechanicData]`(首批留空,本增量填)。机制类:`LeverData{id,coord}`/`DoorData{lever_ids,coord}`/`BridgeData{lever_ids,coord}`/`PortalData{pair_id,coord}`/`DynamicWaterData{period,coord}`。

---

## 文件结构

| 文件 | 职责 | 创建/修改 |
|---|---|---|
| `scripts/tool/mechanic_order_validator.gd` | 路径顺序校验 | Create |
| `tests/tool/test_mechanic_order_validator.gd` | 顺序校验单测 | Create |
| `tests/tool/test_mechanics_integration.gd` | 标注→导出→通关集成 | Create |
| `addons/level_designer/level_canvas.gd` | 画布加机制标注+渲染 | Modify |
| `addons/level_designer/main_view.gd` | 工具栏机制模式+参数+导出前校验 | Modify |

---

## Task 1: MechanicOrderValidator(路径顺序校验)

**Files:**
- Create: `tests/tool/test_mechanic_order_validator.gd`
- Create: `scripts/tool/mechanic_order_validator.gd`

校验规则(spec §4):机关先于门/桥(OR 语义:任一 lever 的 path index < 门/桥 index)、传送对相邻、动态水 LOW(`i % period < (period+1)/2`,i=踏入前 path 长度)。

- [ ] **Step 1: 写失败测试** — Create `tests/tool/test_mechanic_order_validator.gd`

```gdscript
extends GutTest

func test_lever_before_door_passes():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(1, 0)
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    door.coord = Vector2i(2, 0)
    var mechs: Array[MechanicData] = [lever, door]
    assert_eq(MechanicOrderValidator.validate(path, mechs), [])

func test_lever_after_door_fails():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(2, 0)
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    door.coord = Vector2i(1, 0)
    var mechs: Array[MechanicData] = [lever, door]
    var errs := MechanicOrderValidator.validate(path, mechs)
    assert_true(errs.any(func(e: String): return e.find("门") >= 0))

func test_portal_pair_adjacent_passes():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var pa := PortalData.new()
    pa.pair_id = "P1"
    pa.coord = Vector2i(1, 0)
    var pb := PortalData.new()
    pb.pair_id = "P1"
    pb.coord = Vector2i(2, 0)
    var mechs: Array[MechanicData] = [pa, pb]
    assert_eq(MechanicOrderValidator.validate(path, mechs), [])

func test_portal_pair_not_adjacent_fails():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
    var pa := PortalData.new()
    pa.pair_id = "P1"
    pa.coord = Vector2i(1, 0)
    var pb := PortalData.new()
    pb.pair_id = "P1"
    pb.coord = Vector2i(3, 0)
    var mechs: Array[MechanicData] = [pa, pb]
    var errs := MechanicOrderValidator.validate(path, mechs)
    assert_true(errs.any(func(e: String): return e.find("相邻") >= 0))

func test_dynamic_water_low_phase_passes():
    var path: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 0)]
    var dw := DynamicWaterData.new()
    dw.period = 2
    dw.coord = Vector2i(1, 0)
    var mechs: Array[MechanicData] = [dw]
    assert_eq(MechanicOrderValidator.validate(path, mechs), [])

func test_dynamic_water_high_phase_fails():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
    var dw := DynamicWaterData.new()
    dw.period = 2
    dw.coord = Vector2i(1, 0)
    var mechs: Array[MechanicData] = [dw]
    var errs := MechanicOrderValidator.validate(path, mechs)
    assert_true(errs.any(func(e: String): return e.find("低水位") >= 0))
```

> 动态水 period=2:`(2+1)/2=1`(整除),LOW ⟺ `i%2<1` ⟺ i 偶。low 测 index0→LOW✓;high 测 index1→HIGH✓。

- [ ] **Step 2: 跑测试验证失败(红)**

Run: 全部测试命令
Expected: 6 测 FAIL —— `MechanicOrderValidator` 未定义。

- [ ] **Step 3: 实现 MechanicOrderValidator** — Create `scripts/tool/mechanic_order_validator.gd`

```gdscript
class_name MechanicOrderValidator

static func validate(path: Array[Vector2i], mechanics: Array[MechanicData]) -> Array[String]:
    var errors: Array[String] = []
    var index_of: Dictionary = {}
    for i in range(path.size()):
        index_of[path[i]] = i
    var lever_coord_by_id: Dictionary = {}
    for m in mechanics:
        if m is LeverData:
            lever_coord_by_id[(m as LeverData).id] = m.coord
    for m in mechanics:
        if m is DoorData:
            _check_lever_before(errors, "门", m.coord, (m as DoorData).lever_ids, index_of, lever_coord_by_id)
        elif m is BridgeData:
            _check_lever_before(errors, "桥", m.coord, (m as BridgeData).lever_ids, index_of, lever_coord_by_id)
    var portals_by_id: Dictionary = {}
    for m in mechanics:
        if m is PortalData:
            var pid := (m as PortalData).pair_id
            var arr: Array = portals_by_id.get(pid, [])
            arr.append(m.coord)
            portals_by_id[pid] = arr
    for pid in portals_by_id:
        var coords: Array = portals_by_id[pid]
        if coords.size() == 2:
            var ia: int = index_of.get(coords[0], -1)
            var ib: int = index_of.get(coords[1], -1)
            if abs(ia - ib) != 1:
                errors.append("传送对 pair_id '%s' 须相邻(传送步)" % pid)
    for m in mechanics:
        if m is DynamicWaterData:
            var dw := m as DynamicWaterData
            var i: int = index_of.get(dw.coord, -1)
            if i >= 0:
                @warning_ignore("integer_division")
                var low: bool = (i % dw.period) < (dw.period + 1) / 2
                if not low:
                    errors.append("动态水 (%d,%d) 须经低水位经过" % [dw.coord.x, dw.coord.y])
    return errors

static func _check_lever_before(errors: Array[String], label: String, coord: Vector2i, lever_ids: Array[String], index_of: Dictionary, lever_coord_by_id: Dictionary) -> void:
    var my_index: int = index_of.get(coord, -1)
    var has_prior: bool = false
    for lid in lever_ids:
        var lcoord: Variant = lever_coord_by_id.get(lid)
        if lcoord != null:
            var li: int = index_of.get(lcoord, -1)
            if li >= 0 and li < my_index:
                has_prior = true
                break
    if not has_prior:
        errors.append("%s (%d,%d) 未在任何控制机关之前经过" % [label, coord.x, coord.y])
```

- [ ] **Step 4: import + 跑测试验证通过(绿)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 全绿(82 + 新增 6 = 88)。

- [ ] **Step 5: Commit**

```bash
git add scripts/tool/mechanic_order_validator.gd tests/tool/test_mechanic_order_validator.gd
git commit -m "feat(tool): MechanicOrderValidator 路径顺序校验(机关先于门/传送相邻/动态水LOW,TDD)"
```

---

## Task 2: 集成测试(标注含机制关卡 → 导出 → 通关)

**Files:**
- Create: `tests/tool/test_mechanics_integration.gd`

实现已在 Task 1 + MVP Exporter,本 Task 锁定端到端:标注机关+门的关卡经顺序校验 → 导出 → `LevelSystem.load` → 按设计 path move 通关。

- [ ] **Step 1: 写测试** — Create `tests/tool/test_mechanics_integration.gd`

```gdscript
extends GutTest

func test_annotated_door_level_exportable_and_winnable():
    var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
    var w := WorkLevelResource.new()
    w.size = Vector2i(3, 1)
    w.path = path
    w.has_goal = false
    var lever := LeverData.new()
    lever.id = "L1"
    lever.coord = Vector2i(1, 0)
    var door := DoorData.new()
    door.lever_ids = ["L1"]
    door.coord = Vector2i(2, 0)
    w.mechanics.append(lever)
    w.mechanics.append(door)
    assert_eq(MechanicOrderValidator.validate(path, w.mechanics), [])
    var lr := Exporter.export_level(w)
    var ls := LevelSystem.new()
    ls.load(lr)
    ls.path_state.move(Vector2i(1, 0))
    assert_true(ls.path_state.move(Vector2i(2, 0)))
    assert_true(ls.check_win())
```

- [ ] **Step 2: 跑测试验证通过(绿,实现已存)**

Run: 全部测试命令
Expected: 全绿(88 + 新增 1 = 89)。

- [ ] **Step 3: Commit**

```bash
git add tests/tool/test_mechanics_integration.gd
git commit -m "test(tool): 机关+门关卡 标注→导出→通关集成测试"
```

---

## Task 3: LevelCanvas 机制标注 + 渲染(表现层)

**Files:**
- Modify: `addons/level_designer/level_canvas.gd`

画布加:机制模式枚举 + 参数字段;`_gui_input` 按模式分流(NONE=画路径,else=标注/清除);`_draw` 渲染机制格。机制色复用 GridRenderer 值。

- [ ] **Step 1: 改 level_canvas.gd** — 替换整个文件为:

```gdscript
@tool
class_name LevelCanvas
extends Control

enum Mode { NONE, LEVER, DOOR, PORTAL, BRIDGE, DWATER }

var work: WorkLevelResource
var cell_size: int = 48
var mode: Mode = Mode.NONE
var mech_id: String = ""
var mech_lever_ids: Array[String] = []
var mech_period: int = 4

const COLOR_EMPTY := Color(0.96, 0.94, 0.90)
const COLOR_WALL := Color(0.17, 0.17, 0.17)
const COLOR_WATER := Color(0.35, 0.48, 0.54)
const COLOR_PATH := Color(0.95, 0.78, 0.20, 0.65)
const COLOR_GRID := Color(0.50, 0.50, 0.50, 0.4)
const COLOR_LEVER := Color(0.95, 0.78, 0.20)
const COLOR_DOOR := Color(0.45, 0.30, 0.20)
const COLOR_BRIDGE := Color(0.55, 0.40, 0.25)
const COLOR_DWATER := Color(0.62, 0.78, 0.84)
const COLOR_PORTAL := Color(0.55, 0.35, 0.70)

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
    var font := ThemeDB.get_default_theme().default_font
    for m in work.mechanics:
        var c: Vector2i = m.coord
        var rect := Rect2(c.x * cell_size, c.y * cell_size, cell_size, cell_size)
        var color: Color = COLOR_EMPTY
        var label := ""
        if m is LeverData:
            color = COLOR_LEVER
            label = (m as LeverData).id
        elif m is DoorData:
            color = COLOR_DOOR
        elif m is BridgeData:
            color = COLOR_BRIDGE
        elif m is PortalData:
            color = COLOR_PORTAL
            label = (m as PortalData).pair_id
        elif m is DynamicWaterData:
            color = COLOR_DWATER
        draw_rect(rect, color, true)
        if label != "":
            draw_string(font, Vector2(c.x * cell_size + 4, c.y * cell_size + 16), label.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _gui_input(event: InputEvent) -> void:
    if work == null:
        return
    if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
        return
    var coord := Vector2i(int(event.position.x / cell_size), int(event.position.y / cell_size))
    if coord.x < 0 or coord.x >= work.size.x or coord.y < 0 or coord.y >= work.size.y:
        return
    if mode == Mode.NONE:
        _try_append(coord)
    elif coord in work.path:
        _annotate(coord)

func _try_append(coord: Vector2i) -> void:
    if coord in work.path:
        return
    if work.path.size() > 0:
        var last: Vector2i = work.path[work.path.size() - 1]
        if abs(coord.x - last.x) + abs(coord.y - last.y) != 1:
            return
    work.path.append(coord)
    queue_redraw()

func _annotate(coord: Vector2i) -> void:
    for i in range(work.mechanics.size()):
        var m: MechanicData = work.mechanics[i]
        if m.coord == coord and _matches_mode(m):
            work.mechanics.remove_at(i)
            queue_redraw()
            return
    var data: MechanicData = _make_mechanic(coord)
    if data != null:
        work.mechanics.append(data)
        queue_redraw()

func _matches_mode(m: MechanicData) -> bool:
    match mode:
        Mode.LEVER: return m is LeverData
        Mode.DOOR: return m is DoorData
        Mode.BRIDGE: return m is BridgeData
        Mode.PORTAL: return m is PortalData
        Mode.DWATER: return m is DynamicWaterData
    return false

func _make_mechanic(coord: Vector2i) -> MechanicData:
    match mode:
        Mode.LEVER:
            var d := LeverData.new()
            d.id = mech_id
            d.coord = coord
            return d
        Mode.DOOR:
            var d := DoorData.new()
            d.lever_ids = mech_lever_ids
            d.coord = coord
            return d
        Mode.BRIDGE:
            var d := BridgeData.new()
            d.lever_ids = mech_lever_ids
            d.coord = coord
            return d
        Mode.PORTAL:
            var d := PortalData.new()
            d.pair_id = mech_id
            d.coord = coord
            return d
        Mode.DWATER:
            var d := DynamicWaterData.new()
            d.period = mech_period
            d.coord = coord
            return d
    return null
```

- [ ] **Step 2: import + 跑全部测试(确认无破坏)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 89 全绿(表现层不参与 GUT,但确认 import 无错)。

- [ ] **Step 3: Commit**

```bash
git add addons/level_designer/level_canvas.gd
git commit -m "feat(tool): LevelCanvas 机制标注(模式点击)+ 机制格渲染"
```

---

## Task 4: MainView 机制模式工具栏 + 导出前顺序校验

**Files:**
- Modify: `addons/level_designer/main_view.gd`

工具栏加:机制模式 OptionButton + 参数输入(id / lever_ids / period);模式/参数变化同步到 canvas;导出前跑 PathValidator + MechanicOrderValidator,有错不导出。

- [ ] **Step 1: 改 main_view.gd** — 替换整个文件为:

```gdscript
@tool
class_name LevelDesignerMainView
extends Control

var work: WorkLevelResource
var canvas: LevelCanvas
var size_x_spin: SpinBox
var size_y_spin: SpinBox
var goal_check: CheckBox
var mode_option: OptionButton
var id_edit: LineEdit
var lever_ids_edit: LineEdit
var period_spin: SpinBox

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
    goal_check.toggled.connect(_on_goal_toggled)
    toolbar.add_child(goal_check)
    var clear_btn := Button.new()
    clear_btn.text = "清空路径"
    clear_btn.pressed.connect(_on_clear)
    toolbar.add_child(clear_btn)
    var export_btn := Button.new()
    export_btn.text = "导出 .tres"
    export_btn.pressed.connect(_on_export)
    toolbar.add_child(export_btn)
    var mech_bar := HBoxContainer.new()
    vbox.add_child(mech_bar)
    var ml := Label.new()
    ml.text = "机制:"
    mech_bar.add_child(ml)
    mode_option = OptionButton.new()
    mode_option.add_item("无(画路径)", LevelCanvas.Mode.NONE)
    mode_option.add_item("机关", LevelCanvas.Mode.LEVER)
    mode_option.add_item("门", LevelCanvas.Mode.DOOR)
    mode_option.add_item("传送", LevelCanvas.Mode.PORTAL)
    mode_option.add_item("桥", LevelCanvas.Mode.BRIDGE)
    mode_option.add_item("动态水", LevelCanvas.Mode.DWATER)
    mode_option.item_selected.connect(_on_mode_changed)
    mech_bar.add_child(mode_option)
    var idl := Label.new()
    idl.text = "id/pair_id:"
    mech_bar.add_child(idl)
    id_edit = LineEdit.new()
    id_edit.text_changed.connect(_on_param_changed)
    mech_bar.add_child(id_edit)
    var ll := Label.new()
    ll.text = "lever_ids(逗号):"
    mech_bar.add_child(ll)
    lever_ids_edit = LineEdit.new()
    lever_ids_edit.text_changed.connect(_on_param_changed)
    mech_bar.add_child(lever_ids_edit)
    var pl := Label.new()
    pl.text = "period:"
    mech_bar.add_child(pl)
    period_spin = SpinBox.new()
    period_spin.min_value = 2
    period_spin.max_value = 20
    period_spin.value = 4
    period_spin.value_changed.connect(_on_param_changed)
    mech_bar.add_child(period_spin)
    canvas = LevelCanvas.new()
    canvas.work = work
    canvas.cell_size = 48
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    vbox.add_child(canvas)
    _on_mode_changed(0)

func _on_size_changed(_v: float) -> void:
    work.size = Vector2i(int(size_x_spin.value), int(size_y_spin.value))
    var kept: Array[Vector2i] = []
    for c in work.path:
        if c.x < work.size.x and c.y < work.size.y:
            kept.append(c)
    work.path = kept
    canvas.custom_minimum_size = Vector2(work.size.x * canvas.cell_size, work.size.y * canvas.cell_size)
    canvas.queue_redraw()

func _on_goal_toggled(p: bool) -> void:
    work.has_goal = p
    canvas.queue_redraw()

func _on_clear() -> void:
    work.path = []
    canvas.queue_redraw()

func _on_mode_changed(idx: int) -> void:
    canvas.mode = idx as LevelCanvas.Mode
    _on_param_changed()

func _on_param_changed() -> void:
    canvas.mech_id = id_edit.text
    var ids: Array[String] = []
    for s in lever_ids_edit.text.split(",", false):
        ids.append(s.strip_edges())
    canvas.mech_lever_ids = ids
    canvas.mech_period = int(period_spin.value)

func _on_export() -> void:
    var errs := PathValidator.validate(work.path, work.size)
    errs += MechanicOrderValidator.validate(work.path, work.mechanics)
    if errs.size() > 0:
        print("[LevelDesigner] 校验失败,不导出: ", errs)
        return
    var lr := Exporter.export_level(work)
    var path := "res://resources/levels/%s.tres" % work.meta.id
    var err := ResourceSaver.save(lr, path)
    if err == OK:
        print("[LevelDesigner] 已导出: ", path)
        var data_errs := LevelSystem.new().validate(lr)
        if data_errs.size() > 0:
            print("[LevelDesigner] 数据完整性警告(运行时 validate): ", data_errs)
    else:
        print("[LevelDesigner] 导出失败: ", err)
```

- [ ] **Step 2: import + 跑全部测试(确认无破坏)**

Run: `"$GODOT" --headless --path . --import` 然后 全部测试命令
Expected: 89 全绿。

- [ ] **Step 3: 手动验证(必需,表现层)**

1. 编辑器→项目设置→插件→禁用再启用 LevelDesigner(重载新代码)。
2. 进主视图,画一条路径(模式=无)。
3. 选「机关」模式,id 填 `L1`,点路径上某格标注(显示黄色+L 标号);再点同格清除。
4. 选「门」模式,lever_ids 填 `L1`,点机关之后的路径格标注门(棕色)。
5. 点「导出」,控制台输出 `已导出` + 无校验错误。
6. 运行游戏加载导出的 .tres,按设计 path(先机关后门)通关。
7. 反向验证:门标在机关之前,点导出→控制台报「门 ... 未在控制机关之前经过」,不导出。

- [ ] **Step 4: Commit**

```bash
git add addons/level_designer/main_view.gd
git commit -m "feat(tool): MainView 机制模式工具栏+参数+导出前 PathValidator/MechanicOrderValidator 双校验"
```

---

## Task 5: 全量回归 + merge main

- [ ] **Step 1: 全量 GUT 回归**

Run: 全部测试命令
Expected: 全绿(89)。

- [ ] **Step 2: 更新 memory**

更新 `monk-coding-status.md`:机制标注+顺序校验增量完成,测试数更新(82→89),下一步(obstacle 微调/undo/拖拽/自动生成)。

- [ ] **Step 3: merge main(本地)**

```bash
git checkout main
git merge --no-ff feat/level-tool-mechanics
git branch -d feat/level-tool-mechanics
```

- [ ] **Step 4: 提示用户手动 push**

> `git push origin main`(代理限制,push 用户手动)。

---

## 验收对照(spec §8)

- [x] Task 1: MechanicOrderValidator 3 类顺序校验 GUT 全覆盖
- [x] Task 2: 标注含机制关卡→导出→按 path 通关(集成)
- [x] Task 3/4: 5 种机制可标注(参数填 MechanicData)+ 机制格渲染
- [x] Task 4: 导出前 PathValidator + MechanicOrderValidator 双校验;数据完整性复用运行时 validate
- [x] Exporter 不改(mechanics 直传)

## 自审(writing-plans §Self-Review)

1. **Spec coverage**:spec §1 范围 → Task1-4;§4 校验规则 → Task1 代码;§5 标注交互 → Task3/4;§8 验收 → 验收对照。无遗漏。
2. **Placeholder scan**:无 TBD;每步完整代码或确切命令。
3. **Type consistency**:`MechanicOrderValidator.validate(path: Array[Vector2i], mechanics: Array[MechanicData]) -> Array[String]`、`LevelCanvas.Mode` 枚举前后一致。

## 执行中变更(UX 改进,2026-07-12,用户验证反馈触发)

Task3/4 的标注交互在执行后改进,**取代**本 plan 的 Task3/4 代码块:
- **变更**:机关标注自动分配 id(`L<n>`,扫描现有 max+1 避免重复)、门/桥 lever 改从已标机关下拉选(`OptionButton` 单选→`lever_ids=[id]`)、传送自动按标注顺序配对(`pair_id` 自动,偶数开新对/奇数补对)、移除手填 id/pair_id 输入框;另修 `_on_param_changed` 信号连接(去 `_v` 参数——`text_changed` 0 参连 1 参 callable 在 Godot4 运行时报错)。
- **理由**:原手填 id/lever_ids 易漏填/不一致(用户验证时机关 id 与门 lever_ids 均空,`MechanicOrderValidator` 误报「门未在机关之前」);自动分配 + 下拉选杜绝手填错误。
- **实际代码**:`addons/level_designer/level_canvas.gd`(`_make_mechanic`/`_next_lever_id`/`_next_pair_id`)+ `main_view.gd`(`lever_option`/`_refresh_lever_options`/`_on_lever_selected`)。本 plan Task3/4 代码块为原始规划,已被取代,以实际代码为准。
