# 首批关卡 + 章节选关入口 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 monk 实现「章节选关入口」——boot 常驻、选关 UI、内存线性解锁 + 下一关高亮、关卡加载参数化、通关/返回流转,用 GUT 内构关卡验证全链路。

**Architecture:** boot.tscn 作常驻根,实例化 level.tscn 为子节点并注入 LevelResource;解锁/高亮规则抽纯逻辑类 `LevelProgression`(可测),boot.gd 仅做 UI 绑定;level_controller 新增 `won`/`back_requested` 信号,HUD 加「返回列表」按钮。不存档、不引入 autoload 全局状态。

**Tech Stack:** Godot 4.7 / 纯 GDScript / GUT 9.x / Forward+

**Spec:** `docs/superpowers/specs/2026-07-12-first-levels-and-select-design.md`

**运行/测试命令:**
- Godot 可执行(记为 `$GODOT`):`C:\Program Files\godot_engine\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64.exe`
- 改/加 `class_name` 后先重导入:`"$GODOT" --headless --path . --import`
- 跑全部 GUT:`"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- 跑单个测试脚本:`"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/level -gexit`(按目录)或 `-gselect=<test_name>` 按名

**范围声明:**
- ✅ 本 plan:入口系统代码(7 任务)+ GUT 测试(用内构关卡验证流转)
- ⏭️ 后续阶段(非本 plan TDD 任务,plan 末尾):8 关 `.tres` 产出(LevelDesigner 工具,人工)、`chapter_01/02.tres` 引用正式关、端到端人工 QA
- ⏭️ 已后置(见 spec D8):求解器 / 自动可解性验证

---

## File Structure

| 文件 | 责任 | 新增/改 |
|---|---|---|
| `scripts/level/chapter_resource.gd` | 章节数据:id/display_name/main_levels(简化,无 branches/unlock_condition) | 新增 |
| `scripts/level/level_progression.gd` | 纯逻辑:拍平 chapters → 推导 unlocked / highlighted / completed | 新增 |
| `scripts/level/level_controller.gd` | 加 `won`/`back_requested` 信号;通关首次 emit won | 改 |
| `scripts/ui/hud.gd` | 加「返回列表」按钮 + `back_pressed` 信号 | 改 |
| `scripts/ui/boot.gd` | 表现层:加载章节、渲染选关 UI、实例化/移除 level、通关/返回回调 | 新增 |
| `Scenes/boot.tscn` | 根节点挂 boot.gd(替换空 Control 内容) | 改 |
| `tests/level/test_chapter_resource.gd` | ChapterResource 字段测试 | 新增 |
| `tests/level/test_level_progression.gd` | 解锁/跨章/高亮规则测试 | 新增 |
| `tests/level/test_level_controller_signals.gd` | won(首次emit一次)/back_requested 信号测试 | 新增 |
| `tests/ui/test_hud.gd` | 返回按钮 + back_pressed 信号测试 | 新增 |
| `tests/ui/test_boot.gd` | boot 容错初始化(无章节文件不崩)冒烟测试 | 新增 |
| `tests/level/test_levels_valid.gd` | 参数化:遍历 `resources/levels/*.tres`,validate 无错 | 新增 |

---

## Task 1: ChapterResource 数据类

**Files:**
- Create: `scripts/level/chapter_resource.gd`
- Test: `tests/level/test_chapter_resource.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/level/test_chapter_resource.gd`:

```gdscript
extends GutTest

func test_fields_default_empty():
    var ch := ChapterResource.new()
    assert_eq(ch.id, "")
    assert_eq(ch.display_name, "")
    assert_eq(ch.main_levels, [])

func test_fields_assigned():
    var ch := ChapterResource.new()
    ch.id = "ch1"
    ch.display_name = "前院"
    var lr := LevelResource.new()
    ch.main_levels.append(lr)
    assert_eq(ch.id, "ch1")
    assert_eq(ch.display_name, "前院")
    assert_eq(ch.main_levels.size(), 1)
    assert_eq(ch.main_levels[0], lr)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_chapter_resource -gexit`
Expected: FAIL(ChapterResource 未定义 / class_name 不存在)

- [ ] **Step 3: 写最小实现**

创建 `scripts/level/chapter_resource.gd`:

```gdscript
class_name ChapterResource
extends Resource

@export var id: String
@export var display_name: String
@export var main_levels: Array[LevelResource] = []
```

> `main_levels` 显式初始化 `= []`,规避 GDScript 4.7 typed @export Array 未初始化在 `.new()` 后 `.append` 崩的问题(同 LevelResource.tiles 的已知坑)。

- [ ] **Step 4: 重导入(新增 class_name)+ 跑测试确认通过**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_chapter_resource -gexit`
Expected: PASS(2/2)

- [ ] **Step 5: Commit**

```bash
git add scripts/level/chapter_resource.gd tests/level/test_chapter_resource.gd
git commit -m "feat(level): ChapterResource 数据类(简化:id/display_name/main_levels)"
```

---

## Task 2: LevelProgression 纯逻辑(核心)

**Files:**
- Create: `scripts/level/level_progression.gd`
- Test: `tests/level/test_level_progression.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/level/test_level_progression.gd`:

```gdscript
extends GutTest

func _level(id: String) -> LevelResource:
    var lr := LevelResource.new()
    lr.meta = LevelMeta.new()
    lr.meta.id = id
    lr.meta.display_name = id
    return lr

func _chapter(ch_id: String, level_ids: Array) -> ChapterResource:
    var ch := ChapterResource.new()
    ch.id = ch_id
    ch.display_name = ch_id
    for lid in level_ids:
        ch.main_levels.append(_level(lid))
    return ch

func test_initial_unlocks_only_first():
    var ch1 := _chapter("ch1", ["1-1", "1-2", "1-3"])
    var prog := LevelProgression.new([ch1])
    assert_eq(prog.unlocked_ids(), ["1-1"])
    assert_eq(prog.highlighted_id(), "1-1")

func test_unlock_next_after_complete():
    var ch1 := _chapter("ch1", ["1-1", "1-2", "1-3"])
    var prog := LevelProgression.new([ch1])
    prog.mark_completed("1-1")
    assert_eq(prog.unlocked_ids(), ["1-1", "1-2"])
    assert_eq(prog.highlighted_id(), "1-2")

func test_unlock_crosses_chapter_boundary():
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var ch2 := _chapter("ch2", ["2-1", "2-2"])
    var prog := LevelProgression.new([ch1, ch2])
    prog.mark_completed("1-1")
    prog.mark_completed("1-2")
    assert_eq(prog.unlocked_ids(), ["1-1", "1-2", "2-1"])
    assert_eq(prog.highlighted_id(), "2-1")

func test_highlighted_empty_when_all_complete():
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var prog := LevelProgression.new([ch1])
    prog.mark_completed("1-1")
    prog.mark_completed("1-2")
    assert_eq(prog.highlighted_id(), "")

func test_completed_from_init_arg():
    var ch1 := _chapter("ch1", ["1-1", "1-2", "1-3"])
    var prog := LevelProgression.new([ch1], ["1-1"])
    assert_eq(prog.unlocked_ids(), ["1-1", "1-2"])
    assert_true(prog.is_completed("1-1"))
    assert_false(prog.is_completed("1-2"))

func test_empty_chapters_safe():
    var prog := LevelProgression.new([])
    assert_eq(prog.unlocked_ids(), [])
    assert_eq(prog.highlighted_id(), "")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_level_progression -gexit`
Expected: FAIL(LevelProgression 未定义)

- [ ] **Step 3: 写最小实现**

创建 `scripts/level/level_progression.gd`:

```gdscript
class_name LevelProgression
extends RefCounted

var _sequence: Array[String] = []
var _completed: Dictionary = {}

func _init(chapters: Array, completed: Array = []) -> void:
	for ch in chapters:
		var chapter: ChapterResource = ch as ChapterResource
		for lvl in chapter.main_levels:
			var level: LevelResource = lvl as LevelResource
			_sequence.append(level.meta.id)
	for id in completed:
		_completed[id] = true

func unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	if _sequence.is_empty():
		return result
	result.append(_sequence[0])
	for i in range(_sequence.size() - 1):
		if _completed.has(_sequence[i]):
			result.append(_sequence[i + 1])
	return result

func highlighted_id() -> String:
	for id in _sequence:
		if not _completed.has(id):
			return id
	return ""

func mark_completed(level_id: String) -> void:
	_completed[level_id] = true

func is_completed(level_id: String) -> bool:
	return _completed.has(level_id)
```

> 线性规则:序列首关总解锁;通关第 N 关解锁第 N+1 关(跨章自然衔接,因序列是跨章拍平的)。`highlighted` = 首个未通关关(必已解锁,因其前驱已通关)。纯函数式,无副作用。

- [ ] **Step 4: 重导入 + 跑测试确认通过**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_level_progression -gexit`
Expected: PASS(6/6)

- [ ] **Step 5: Commit**

```bash
git add scripts/level/level_progression.gd tests/level/test_level_progression.gd
git commit -m "feat(level): LevelProgression 线性解锁/高亮纯逻辑(TDD)"
```

---

## Task 3: level_controller 加 won / back_requested 信号

**Files:**
- Modify: `scripts/level/level_controller.gd`
- Test: `tests/level/test_level_controller_signals.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/level/test_level_controller_signals.gd`:

```gdscript
extends GutTest

const LevelScene := preload("res://Scenes/level.tscn")

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

func _make_ctrl(w: int, h: int) -> Node:
    var ctrl := LevelScene.instantiate()
    ctrl.level = _flat_level(w, h)
    add_child(ctrl)
    return ctrl

func test_won_emits_once_on_cover():
    var ctrl := _make_ctrl(2, 1)
    var count := 0
    ctrl.won.connect(func(): count += 1)
    ctrl._on_move_intent(Vector2i(1, 0))
    assert_eq(count, 1)

func test_won_does_not_reemit_on_redundant_move():
    var ctrl := _make_ctrl(2, 1)
    var count := 0
    ctrl.won.connect(func(): count += 1)
    ctrl._on_move_intent(Vector2i(1, 0))
    ctrl._on_move_intent(Vector2i(1, 0))
    assert_eq(count, 1)

func test_won_resets_after_reset_request():
    var ctrl := _make_ctrl(2, 1)
    var count := 0
    ctrl.won.connect(func(): count += 1)
    ctrl._on_move_intent(Vector2i(1, 0))
    ctrl._on_reset()
    ctrl._on_move_intent(Vector2i(1, 0))
    assert_eq(count, 2)

func test_back_requested_emits_on_hud_back():
    var ctrl := _make_ctrl(2, 1)
    var emitted := false
    ctrl.back_requested.connect(func(): emitted = true)
    ctrl._hud.back_pressed.emit()
    assert_true(emitted)
```

> 2×1 关:需扫格 = [(0,0),(1,0)];`move(1,0)` 后 path 覆盖 → `check_win` true → emit won。`_on_reset` 重建 path_state 并 `_check_win([])` → 未覆盖 → `_won` 复位,故再次通关会二次 emit。

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_level_controller_signals -gexit`
Expected: FAIL(ctrl 上无 `won`/`back_requested` 信号)

- [ ] **Step 3: 改 level_controller.gd**

在 `scripts/level/level_controller.gd` 顶部信号区(现有 `class_name`/`extends`/`@export` 之后)新增信号与状态:

```gdscript
signal won()
signal back_requested()

var _won: bool = false
```

在 `_ready()` 末尾(`_check_win([])` 之前)新增一行,把 HUD 的返回按钮接到 `back_requested`:

```gdscript
    _hud.back_pressed.connect(func(): back_requested.emit())
```

把 `_check_win` 改为「首次通关 emit 一次,撤销/重置后复位」:

```gdscript
func _check_win(_p: Array) -> void:
    if _level_system.check_win():
        if not _won:
            _won = true
            won.emit()
        _hud.show_win()
    else:
        _won = false
        _hud.clear_win()
```

> 改动最小:仅 +信号/+`_won`/+1 行 hud 连接,`_check_win` 加边沿 emit。`_on_reset` 不改(其内部 `_check_win([])` 会经 else 分支复位 `_won`)。

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_level_controller_signals -gexit`
Expected: PASS(4/4)

- [ ] **Step 5: 回归全部测试**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 既有 106 + 新增测试全绿(无回归)

- [ ] **Step 6: Commit**

```bash
git add scripts/level/level_controller.gd tests/level/test_level_controller_signals.gd
git commit -m "feat(level): level_controller 加 won/back_requested 信号(通关首次emit)"
```

---

## Task 4: HUD 加「返回列表」按钮

**Files:**
- Modify: `scripts/ui/hud.gd`
- Test: `tests/ui/test_hud.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/ui/test_hud.gd`:

```gdscript
extends GutTest

func test_has_back_button():
    var hud := HUD.new()
    add_child(hud)
    var found := false
    for c in hud.get_children():
        if c is Button and (c as Button).text == "返回列表":
            found = true
    assert_true(found)

func test_back_pressed_signal_wired():
    var hud := HUD.new()
    add_child(hud)
    var emitted := false
    hud.back_pressed.connect(func(): emitted = true)
    hud.back_pressed.emit()
    assert_true(emitted)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_hud -gexit`
Expected: FAIL(无「返回列表」按钮 / 无 back_pressed 信号)

- [ ] **Step 3: 改 hud.gd**

在 `scripts/ui/hud.gd` 信号区新增:

```gdscript
signal back_pressed()
```

在 `_ready()` 中,`reset` 按钮创建之后、`_win_label` 创建之前,新增返回按钮(reset 在 x=110 宽约 100,返回放 x=210):

```gdscript
    var back := Button.new()
    back.text = "返回列表"
    back.position = Vector2(210, 10)
    back.pressed.connect(func(): back_pressed.emit())
    add_child(back)
```

- [ ] **Step 4: 跑测试确认通过**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_hud -gexit`
Expected: PASS(2/2)

- [ ] **Step 5: 回归全部测试**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全绿

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/hud.gd tests/ui/test_hud.gd
git commit -m "feat(ui): HUD 加返回列表按钮 + back_pressed 信号"
```

---

## Task 5: boot.gd 表现层

**Files:**
- Create: `scripts/ui/boot.gd`
- Test: `tests/ui/test_boot.gd`

> boot 的解锁/高亮**逻辑**由 Task 2 的 LevelProgression 覆盖。boot.gd 是表现层(UI 绑定 + 场景实例化),GUT 只做容错冒烟(无章节文件不崩);完整 UI 交互由 Task 6 后的人工 QA 验证。

- [ ] **Step 1: 写失败测试**

创建 `tests/ui/test_boot.gd`:

```gdscript
extends GutTest

func test_ready_safe_without_chapter_files():
    var boot := Boot.new()
    add_child(boot)
    assert_not_null(boot._progression)
    assert_eq(boot._chapters, [])

func test_level_instance_cleaned_on_exit():
    var boot := Boot.new()
    add_child(boot)
    boot._exit_level()
    assert_true(boot._level_instance == null)
```

> `_progression`/`_chapters`/`_level_instance` 为 boot 内部状态,测试白盒访问(GDScript 允许)。`_exit_level` 在无实例时也应安全(null 检查)。

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_boot -gexit`
Expected: FAIL(Boot 未定义)

- [ ] **Step 3: 写实现**

创建 `scripts/ui/boot.gd`:

```gdscript
class_name Boot
extends Control

const LevelScene := preload("res://Scenes/level.tscn")

@export var chapter_paths: Array[String] = [
	"res://resources/chapters/chapter_01.tres",
	"res://resources/chapters/chapter_02.tres",
]

var _chapters: Array[ChapterResource] = []
var _progression: LevelProgression
var _select_container: VBoxContainer
var _level_instance: Node

func _ready() -> void:
	_load_chapters()
	_progression = LevelProgression.new(_chapters)
	_build_select_ui()

func _load_chapters() -> void:
	_chapters = []
	for path in chapter_paths:
		if ResourceLoader.exists(path):
			var ch := load(path) as ChapterResource
			if ch != null:
				_chapters.append(ch)

func _build_select_ui() -> void:
	for c in get_children():
		c.queue_free()
	_select_container = VBoxContainer.new()
	_select_container.position = Vector2(20, 20)
	_select_container.size = Vector2(400, 600)
	add_child(_select_container)
	var unlocked := _progression.unlocked_ids()
	var highlighted := _progression.highlighted_id()
	for ch in _chapters:
		var title := Label.new()
		title.text = ch.display_name
		_select_container.add_child(title)
		for lvl in ch.main_levels:
			var level: LevelResource = lvl as LevelResource
			var id: String = level.meta.id
			var btn := Button.new()
			btn.text = level.meta.display_name
			if _progression.is_completed(id):
				btn.text = "✓ " + btn.text
			if id == highlighted:
				btn.text = "▶ " + btn.text
			btn.disabled = not (id in unlocked)
			btn.pressed.connect(_on_level_selected.bind(level))
			_select_container.add_child(btn)

func _on_level_selected(level: LevelResource) -> void:
	if _select_container != null:
		_select_container.visible = false
	_level_instance = LevelScene.instantiate()
	_level_instance.level = level
	_level_instance.won.connect(_on_level_won)
	_level_instance.back_requested.connect(_on_level_back)
	add_child(_level_instance)

func _on_level_won() -> void:
	var id: String = (_level_instance.level as LevelResource).meta.id
	_progression.mark_completed(id)
	_exit_level()

func _on_level_back() -> void:
	_exit_level()

func _exit_level() -> void:
	if _level_instance != null:
		_level_instance.queue_free()
		_level_instance = null
	if _select_container != null:
		_build_select_ui()
		_select_container.visible = true
```

> `chapter_paths` 默认指向后续阶段产出的 `chapter_01/02.tres`;文件不存在时 `ResourceLoader.exists` 跳过 → `_chapters` 空 → 选关 UI 空(已知状态,关卡产出前)。`_level_instance.level = level` 在 `add_child` 前注入,`level_controller._ready` 时 level 已就位。

- [ ] **Step 4: 重导入 + 跑测试确认通过**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_boot -gexit`
Expected: PASS(2/2)

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/boot.gd tests/ui/test_boot.gd
git commit -m "feat(ui): boot.gd 表现层(加载章节/选关UI/实例化level/通关返回)"
```

---

## Task 6: boot.tscn 挂脚本 + level.tscn 约定

**Files:**
- Modify: `Scenes/boot.tscn`
- Modify(约定,无实质改动): `Scenes/level.tscn`

- [ ] **Step 1: 改 boot.tscn**

把 `Scenes/boot.tscn` 内容改为(保留原 `uid="uid://bapoleovhc5bw"`,根节点挂 boot.gd):

```
[gd_scene load_steps=2 format=3 uid="uid://bapoleovhc5bw"]

[ext_resource type="Script" path="res://scripts/ui/boot.gd" id="1_boot"]

[node name="Boot" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_boot")
```

- [ ] **Step 2: level.tscn 约定(不改文件)**

`Scenes/level.tscn` 现状 `level = ExtResource("1_lvl")` 指向 `test_level_01.tres`,**保持不变**——作为单独运行 `level.tscn` 时的开发 fallback。boot 注入关卡时在 `add_child` 前覆盖 `level_controller.level`,优先级高于 tscn 默认值。**此步无代码改动**,仅记录约定。

- [ ] **Step 3: 重导入 + 跑全部测试确认无回归**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全绿(场景改动不影响 GUT 逻辑测试)

- [ ] **Step 4: 人工冒烟(编辑器)**

1. 编辑器打开项目 → F5(主场景 boot.tscn)
2. 预期:启动即 boot 选关 UI;因无 chapter_01/02.tres,列表为空(不崩)
3. 单独运行 level.tscn:仍正常加载 test_level_01 可玩(fallback 有效)

- [ ] **Step 5: Commit**

```bash
git add Scenes/boot.tscn
git commit -m "feat(scene): boot.tscn 挂 boot.gd(选关入口主场景)"
```

---

## Task 7: test_levels_valid 参数化校验(关卡就绪脚手架)

**Files:**
- Create: `tests/level/test_levels_valid.gd`

> 为后续 8 关就绪:遍历 `resources/levels/*.tres`,每关 `LevelSystem.validate()` 必须无错。现以 test_level_01~03 验证脚手架正确,未来 `l*.tres` 自动覆盖。

- [ ] **Step 1: 写测试**

创建 `tests/level/test_levels_valid.gd`:

```gdscript
extends GutTest

func _all_level_paths() -> Array:
    var dir := DirAccess.open("res://resources/levels")
    assert_not_null(dir, "无法打开 resources/levels")
    var paths: Array = []
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.ends_with(".tres"):
            paths.append("res://resources/levels/" + name)
        name = dir.get_next()
    dir.list_dir_end()
    return paths

func test_all_levels_validate_clean():
    var paths := _all_level_paths()
    assert_true(paths.size() > 0, "levels 目录应为非空")
    for path in paths:
        var lr := load(path) as LevelResource
        assert_not_null(lr, "加载失败: %s" % path)
        var ls := LevelSystem.new()
        var errs := ls.validate(lr)
        assert_eq(errs, [], "校验出错 %s: %s" % [path, errs])
```

> GUT 无内置参数化,用目录遍历 + 循环断言实现等价效果;失败信息含具体文件路径与错误。

- [ ] **Step 2: 跑测试确认通过**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_levels_valid -gexit`
Expected: PASS(test_level_01~03 均校验通过)

- [ ] **Step 3: 回归全部测试**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全绿

- [ ] **Step 4: Commit**

```bash
git add tests/level/test_levels_valid.gd
git commit -m "test(level): 参数化校验所有 levels/*.tres validate 无错(关卡就绪脚手架)"
```

---

## 后续阶段(非本 plan TDD 任务)

以下在入口代码 merge 后、作为独立设计/内容阶段执行,**不**由本 plan 的 subagent 任务覆盖:

### A. 产出 8 关 `.tres`(`resources/levels/l1_1.tres … l2_3.tres`)

- 编辑器 → 项目设置 → 插件 → 启用 LevelDesigner
- 按蓝图(spec §8 / Task 蓝图表)逐关:PathGenerator 骨架(章节1)或手画解(1-5/章节2)→ Filler 填障碍 → 标注 meta(`id`=`1-1` 等、`display_name`、`difficulty`)→ 机制关标注 Door/Lever + MechanicOrderValidator 校验 → 导出
- 每关导出后:本 plan Task 7 的 `test_levels_valid` 自动覆盖校验

### B. 章节资源(`resources/chapters/chapter_01.tres`、`chapter_02.tres`)

- 编辑器建 ChapterResource:`chapter_01`(前院,main_levels = l1_1~l1_5)、`chapter_02`(后山,l2_1~l2_3)
- boot.gd 的 `chapter_paths` 默认值已指向这两个路径,建好后 boot 自动加载

### C. 端到端人工 QA

- F5 运行:启动选关 UI,初始仅 1-1 可点且高亮(▶)
- 逐关玩通 8 关;每关通关 → 回列表、下一关解锁 + 高亮、本关标 ✓
- 验证难度递进、门机关引导(机关靠近门)、无频繁死局挫败
- 全通关后 highlighted 消失

### D. 复盘

- 关卡设计指南补入首批 8 关实例(spec §11 验收末项)

### E. 求解器(spec D8,待讨论)

- 自动可解性验证:DFS 基于 `PathState.move/undo` 的机制语义覆盖、性能、求解器自身正确性测试——实现难度另行讨论,确定后补 spec + plan

---

## Self-Review(plan 自检)

**1. Spec 覆盖**:
- D1 boot 常驻 → Task 5(boot.gd add/remove child)+ Task 6(boot.tscn)✅
- D2 通关回列表 + 高亮 → Task 2(LevelProgression highlighted)+ Task 5(_on_level_won/_exit_level)✅
- D3 ChapterResource 简化 → Task 1 ✅(branches/unlock_condition 不做,后续阶段 B)
- D4 解锁逻辑抽 LevelProgression → Task 2 ✅
- D5 不存档 → 内存状态(Task 5 _progression),无 SaveSystem 任务 ✅(符合)
- D6 生产混合 / D7 难度递进 / 8 关蓝图 → 后续阶段 A(人工产关,非 TDD)✅(已声明范围)
- D8 求解器后置 → 后续阶段 E ✅
- 组件改动清单 spec §6 全覆盖:ChapterResource(T1)/LevelProgression(T2)/level_controller(T3)/hud(T4)/boot.gd(T5)/boot.tscn(T6)/level.tscn 约定(T6)✅;chapter_01/02.tres + 8 关(后续 A/B)

**2. 占位符扫描**:无 TBD/TODO;每代码步骤含完整代码;关卡产出明确归入"后续阶段"而非占位 ✅

**3. 类型一致性**:`LevelProgression.unlocked_ids()->Array[String]`/`highlighted_id()->String`/`mark_completed(String)`/`is_completed(String)->bool` 在 Task 2 定义、Task 5 boot.gd 调用一致;`won()`/`back_requested()` 信号 Task 3 定义、Task 5 连接一致;`HUD.back_pressed` Task 4 定义、Task 3(_hud.back_pressed.emit)与 Task 5 不直接用(boot 连 level_controller.back_requested)一致;`level_controller.level` 注入 Task 3 测试、Task 5 `_level_instance.level = level` 一致 ✅

**4. 已知边界**:
- Task 3 测试访问 `ctrl._on_move_intent` / `ctrl._hud`(白盒),GDScript 允许
- Task 5 测试访问 `boot._progression`/`_chapters`/`_level_instance`/`_exit_level`(白盒)
- boot 完整 UI 交互靠后续阶段 C 人工 QA(无 chapter.tres 时 GUT 无法测选关)
