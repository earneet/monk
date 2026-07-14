# 两级地图式选关菜单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `boot.gd` 的单级 VBox 选关列表重设计为两级地图菜单(第一级分立世界岛屿 + 第二级关卡路径地图 + 伪 Zoom 过渡),布局坐标用独立 `WorldMapLayout` Resource,菜单抽成独立模块,复用 `LevelProgression` 解锁逻辑。

**Architecture:** 新建 `scripts/ui/level_menu/`(三视图脚本)+ `Scenes/level_menu.tscn`;布局数据 `scripts/level/world_map_layout.gd` 等 3 个独立 Resource 脚本 + 首份 `resources/menu/world_map_layout.tres`(headless 脚本生成);`boot.gd` 瘦身为协调者,保留 `_chapters`/`_progression`/`_level_instance`/`_exit_level` 维持现有 `test_boot` 契约。

**Tech Stack:** Godot 4.7 / 纯 GDScript / Forward+ / GUT 9.7.1

**上游 spec:** `docs/superpowers/specs/2026-07-14-two-level-level-menu-design.md`

**环境(每个任务通用):**
```bash
export GODOT="/c/Program Files/godot_engine/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64.exe"
# 改/加 class_name 后先 import:
"$GODOT" --headless --path . --import
# 跑全部测试:
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
# 跑单个测试文件:
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=<ClassName>
```
> 跑完测试后若 `project.godot` 被 headless 改动(editor_plugins/main_scene 副作用),`git restore project.godot` 丢弃(除非本任务有意改它)。

---

## 文件结构

| 文件 | 责任 | 新/改 |
|---|---|---|
| `scripts/level/level_map_entry.gd` | `LevelMapEntry`:关卡在章节路径画布的坐标 | 新 |
| `scripts/level/chapter_map_entry.gd` | `ChapterMapEntry`:岛屿在世界画布的坐标+主题+内含关卡坐标 | 新 |
| `scripts/level/world_map_layout.gd` | `WorldMapLayout`:画布尺寸+岛屿列表+`validate()` 校验 | 新 |
| `tests/level/test_world_map_layout.gd` | 数据类字段 + `validate` 校验逻辑 | 新 |
| `scripts/tool/generate_world_map_layout.gd` | headless 产 `world_map_layout.tres`(spec §8 坐标) | 新 |
| `resources/menu/world_map_layout.tres` | 首份布局(脚本产出) | 新 |
| `tests/tool/test_world_map_layout_generated.gd` | 产出契约(2 章 8 关坐标齐全+校验通过) | 新 |
| `scripts/ui/level_menu/chapter_path_view.gd` | 第二级:路径节点+返回按钮;emit `level_selected`/`back_to_world` | 新 |
| `scripts/ui/level_menu/world_map_view.gd` | 第一级:岛屿+滚动+连线;emit `chapter_selected` | 新 |
| `scripts/ui/level_menu/level_menu.gd` | 两级协调+伪 Zoom Tween+状态机;emit `level_chosen` | 新 |
| `Scenes/level_menu.tscn` | 根挂 `level_menu.gd`,含两 view 子节点 | 新 |
| `tests/ui/test_level_menu.gd` | 视图构建(节点数)+信号+状态转换 | 新 |
| `scripts/ui/boot.gd` | 去 VBox;实例化 `LevelMenu`;保留测试依赖字段 | 改 |
| `Scenes/boot.tscn` | (基本不变,仅挂脚本) | 改(约定) |
| `tests/ui/test_boot.gd` | 适配:layout 缺失降级 | 改 |

**类型约定(全程一致):**
- `WorldMapLayout.validate(loaded_chapters: Array) -> Array[String]`(空=合法)
- `ChapterPathView.build(entries: Array, chapter: ChapterResource, progression: LevelProgression, theme_color: Color) -> void`;signal `level_selected(level: LevelResource)`、`back_to_world()`
- `WorldMapView.build(layout: WorldMapLayout, chapters: Array, progression: LevelProgression) -> void`;signal `chapter_selected(chapter_id: String, anchor: Vector2)`
- `LevelMenu.setup(chapters: Array, layout: WorldMapLayout, progression: LevelProgression) -> void`、`refresh() -> void`;signal `level_chosen(level: LevelResource)`

---

## Task 1: WorldMapLayout 数据类(3 个 Resource 脚本)

**Files:**
- Create: `scripts/level/level_map_entry.gd`
- Create: `scripts/level/chapter_map_entry.gd`
- Create: `scripts/level/world_map_layout.gd`
- Test: `tests/level/test_world_map_layout.gd`

- [ ] **Step 1: 写失败测试(字段默认值 + 赋值 + 嵌套)**

`tests/level/test_world_map_layout.gd`:
```gdscript
extends GutTest

func test_level_map_entry_defaults():
    var e := LevelMapEntry.new()
    assert_eq(e.level_id, "")
    assert_eq(e.position, Vector2.ZERO)

func test_chapter_map_entry_defaults():
    var e := ChapterMapEntry.new()
    assert_eq(e.chapter_id, "")
    assert_eq(e.position, Vector2.ZERO)
    assert_eq(e.theme_color, Color.BLACK)
    assert_eq(e.icon, "")
    assert_eq(e.path_size, Vector2.ZERO)
    assert_eq(e.levels, [])

func test_layout_defaults_and_nest():
    var layout := WorldMapLayout.new()
    assert_eq(layout.canvas_size, Vector2.ZERO)
    assert_eq(layout.chapters, [])
    var ch := ChapterMapEntry.new()
    ch.chapter_id = "ch1"
    ch.position = Vector2(10, 20)
    var lvl := LevelMapEntry.new()
    lvl.level_id = "1-1"
    lvl.position = Vector2(5, 5)
    ch.levels = [lvl]
    layout.chapters = [ch]
    assert_eq(layout.chapters.size(), 1)
    assert_eq((layout.chapters[0] as ChapterMapEntry).levels.size(), 1)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_world_map_layout`
Expected: FAIL(类未定义 / Identifier not found)

- [ ] **Step 3: 写最小实现**

`scripts/level/level_map_entry.gd`:
```gdscript
class_name LevelMapEntry
extends Resource

@export var level_id: String
@export var position: Vector2
```

`scripts/level/chapter_map_entry.gd`:
```gdscript
class_name ChapterMapEntry
extends Resource

@export var chapter_id: String
@export var position: Vector2
@export var theme_color: Color = Color.BLACK
@export var icon: String
@export var path_size: Vector2
@export var levels: Array[LevelMapEntry] = []
```

`scripts/level/world_map_layout.gd`:
```gdscript
class_name WorldMapLayout
extends Resource

@export var canvas_size: Vector2
@export var chapters: Array[ChapterMapEntry] = []
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS(3 test)

- [ ] **Step 5: 提交**

```bash
git add scripts/level/level_map_entry.gd scripts/level/chapter_map_entry.gd scripts/level/world_map_layout.gd tests/level/test_world_map_layout.gd
git commit -m "$(cat <<'EOF'
feat(level-menu): WorldMapLayout 布局数据类 + 字段测试

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: WorldMapLayout 校验逻辑

**Files:**
- Modify: `scripts/level/world_map_layout.gd`(加 `validate`)
- Test: `tests/level/test_world_map_layout.gd`(追加用例)

- [ ] **Step 1: 写失败测试(校验:合法空 / 缺坐标 / id 不匹配 / 顺序错)**

追加到 `tests/level/test_world_map_layout.gd`:
```gdscript
func _level_res(id: String) -> LevelResource:
    var lr := LevelResource.new()
    lr.meta = LevelMeta.new()
    lr.meta.id = id
    return lr

func _chapter_res(cid: String, level_ids: Array) -> ChapterResource:
    var ch := ChapterResource.new()
    ch.id = cid
    for lid in level_ids:
        ch.main_levels.append(_level_res(lid))
    return ch

func _entry(cid: String, level_ids: Array) -> ChapterMapEntry:
    var e := ChapterMapEntry.new()
    e.chapter_id = cid
    for lid in level_ids:
        var le := LevelMapEntry.new()
        le.level_id = lid
        e.levels.append(le)
    return e

func test_validate_ok_returns_empty():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("ch1", ["1-1", "1-2"]), _entry("ch2", ["2-1"])]
    var chapters := [_chapter_res("ch1", ["1-1", "1-2"]), _chapter_res("ch2", ["2-1"])]
    assert_eq(layout.validate(chapters), [])

func test_validate_missing_level_position():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("ch1", ["1-1"])]
    var chapters := [_chapter_res("ch1", ["1-1", "1-2"])]
    var errors := layout.validate(chapters)
    assert_true(errors.any(func(e): return e.find("1-2") >= 0))

func test_validate_unknown_chapter_id():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("chX", ["1-1"])]
    var chapters := [_chapter_res("ch1", ["1-1"])]
    var errors := layout.validate(chapters)
    assert_true(errors.any(func(e): return e.find("chX") >= 0 or e.find("ch1") >= 0))

func test_validate_wrong_order():
    var layout := WorldMapLayout.new()
    layout.chapters = [_entry("ch1", ["1-2", "1-1"])]
    var chapters := [_chapter_res("ch1", ["1-1", "1-2"])]
    var errors := layout.validate(chapters)
    assert_true(errors.any(func(e): return e.find("顺序") >= 0))
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_world_map_layout`
Expected: FAIL(`validate` 不存在)

- [ ] **Step 3: 写最小实现**

追加到 `scripts/level/world_map_layout.gd`(类体内):
```gdscript
func validate(loaded_chapters: Array) -> Array[String]:
    var errors: Array[String] = []
    var loaded: Dictionary = {}
    for ch in loaded_chapters:
        var c: ChapterResource = ch as ChapterResource
        loaded[c.id] = c
    var layout_ids: Dictionary = {}
    for entry in chapters:
        var e: ChapterMapEntry = entry as ChapterMapEntry
        if layout_ids.has(e.chapter_id):
            errors.append("重复的 chapter_id: %s" % e.chapter_id)
        layout_ids[e.chapter_id] = true
    for cid in layout_ids:
        if not loaded.has(cid):
            errors.append("布局含未知 chapter_id: %s" % cid)
    for cid in loaded:
        if not layout_ids.has(cid):
            errors.append("章节 %s 缺布局坐标" % cid)
    for entry in chapters:
        var e: ChapterMapEntry = entry as ChapterMapEntry
        if not loaded.has(e.chapter_id):
            continue
        var ch: ChapterResource = loaded[e.chapter_id] as ChapterResource
        var meta_ids: Array[String] = []
        for lvl in ch.main_levels:
            meta_ids.append((lvl as LevelResource).meta.id)
        var layout_lvl: Dictionary = {}
        for le in e.levels:
            layout_lvl[(le as LevelMapEntry).level_id] = true
        for mid in meta_ids:
            if not layout_lvl.has(mid):
                errors.append("章节 %s 缺关卡 %s 坐标" % [e.chapter_id, mid])
        for lid in layout_lvl:
            if not (lid in meta_ids):
                errors.append("章节 %s 布局含未知关卡 %s" % [e.chapter_id, lid])
        if e.levels.size() == meta_ids.size():
            for i in range(e.levels.size()):
                if (e.levels[i] as LevelMapEntry).level_id != meta_ids[i]:
                    errors.append("章节 %s 关卡顺序不一致(位置 %d)" % [e.chapter_id, i])
                    break
    return errors
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS(全部用例)

- [ ] **Step 5: 提交**

```bash
git add scripts/level/world_map_layout.gd tests/level/test_world_map_layout.gd
git commit -m "$(cat <<'EOF'
feat(level-menu): WorldMapLayout.validate 校验(id 一一对应+反向覆盖+顺序)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 首份 world_map_layout.tres 生成脚本 + 契约测试

**Files:**
- Create: `scripts/tool/generate_world_map_layout.gd`
- Create: `resources/menu/world_map_layout.tres`(脚本产出)
- Test: `tests/tool/test_world_map_layout_generated.gd`

- [ ] **Step 1: 写失败测试(产出契约)**

`tests/tool/test_world_map_layout_generated.gd`:
```gdscript
extends GutTest

const LAYOUT_PATH := "res://resources/menu/world_map_layout.tres"

func test_layout_exists_and_validates():
    assert_true(ResourceLoader.exists(LAYOUT_PATH), "world_map_layout.tres 未生成")
    var layout := load(LAYOUT_PATH) as WorldMapLayout
    assert_not_null(layout)
    var ch1 := load("res://resources/chapters/chapter_01.tres") as ChapterResource
    var ch2 := load("res://resources/chapters/chapter_02.tres") as ChapterResource
    assert_eq(layout.validate([ch1, ch2]), [])

func test_layout_has_two_chapters_and_counts():
    var layout := load(LAYOUT_PATH) as WorldMapLayout
    assert_eq(layout.chapters.size(), 2)
    assert_eq((layout.chapters[0] as ChapterMapEntry).levels.size(), 5)
    assert_eq((layout.chapters[1] as ChapterMapEntry).levels.size(), 3)

func test_level_ids_match_actual_meta():
    var layout := load(LAYOUT_PATH) as WorldMapLayout
    var ch1_entry := layout.chapters[0] as ChapterMapEntry
    var ch1 := load("res://resources/chapters/chapter_01.tres") as ChapterResource
    for i in range(ch1_entry.levels.size()):
        var lid: String = (ch1_entry.levels[i] as LevelMapEntry).level_id
        var mid: String = (ch1.main_levels[i] as LevelResource).meta.id
        assert_eq(lid, mid)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_world_map_layout_generated`
Expected: FAIL(资源不存在)

- [ ] **Step 3: 写生成脚本**

`scripts/tool/generate_world_map_layout.gd`:
```gdscript
extends SceneTree

const LAYOUT_PATH := "res://resources/menu/world_map_layout.tres"
const CH1_PATH := "res://resources/chapters/chapter_01.tres"
const CH2_PATH := "res://resources/chapters/chapter_02.tres"

var _exit_code := 0

func _init() -> void:
    _run()
    quit(_exit_code)

func _run() -> void:
    DirAccess.make_dir_recursive_absolute("res://resources/menu/")
    var layout := WorldMapLayout.new()
    layout.canvas_size = Vector2(720, 1280)
    var ch1 := _chapter("ch1", Vector2(360, 320), Color(0.42, 0.56, 0.35), "🏯", Vector2(720, 960))
    ch1.levels = _levels(["1-1", "1-2", "1-3", "1-4", "1-5"],
        [Vector2(140, 140), Vector2(360, 260), Vector2(560, 400), Vector2(320, 580), Vector2(180, 780)])
    var ch2 := _chapter("ch2", Vector2(360, 820), Color(0.55, 0.42, 0.26), "⛰️", Vector2(720, 760))
    ch2.levels = _levels(["2-1", "2-2", "2-3"],
        [Vector2(160, 180), Vector2(440, 360), Vector2(300, 600)])
    layout.chapters = [ch1, ch2]
    var chapters := [load(CH1_PATH) as ChapterResource, load(CH2_PATH) as ChapterResource]
    var errors := layout.validate(chapters)
    if not errors.is_empty():
        for e in errors:
            push_error(e)
        _exit_code = 1
        return
    var err := ResourceSaver.save(layout, LAYOUT_PATH)
    if err != OK:
        push_error("保存失败: %s" % err)
        _exit_code = 1
        return
    print("world_map_layout.tres 已生成")

func _chapter(cid: String, pos: Vector2, color: Color, icon: String, path_size: Vector2) -> ChapterMapEntry:
    var e := ChapterMapEntry.new()
    e.chapter_id = cid
    e.position = pos
    e.theme_color = color
    e.icon = icon
    e.path_size = path_size
    return e

func _levels(ids: Array, positions: Array) -> Array[LevelMapEntry]:
    var out: Array[LevelMapEntry] = []
    for i in range(ids.size()):
        var le := LevelMapEntry.new()
        le.level_id = ids[i]
        le.position = positions[i]
        out.append(le)
    return out
```

- [ ] **Step 4: 产出 .tres**

Run: `"$GODOT" --headless --path . -s res://scripts/tool/generate_world_map_layout.gd`
Expected: 输出 `world_map_layout.tres 已生成`,退出码 0

- [ ] **Step 5: 跑契约测试确认通过**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_world_map_layout_generated`
Expected: PASS(3 test)

- [ ] **Step 6: 提交**

```bash
git add scripts/tool/generate_world_map_layout.gd resources/menu/world_map_layout.tres tests/tool/test_world_map_layout_generated.gd
git commit -m "$(cat <<'EOF'
feat(level-menu): 首份 world_map_layout.tres(spec §8 坐标)+ 契约测试

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: ChapterPathView(第二级关卡路径视图)

**Files:**
- Create: `scripts/ui/level_menu/chapter_path_view.gd`
- Test: `tests/ui/test_level_menu.gd`(本任务起逐步追加)

- [ ] **Step 1: 写失败测试(节点数 + 信号)**

`tests/ui/test_level_menu.gd`:
```gdscript
extends GutTest

func _prog(chapters: Array, completed: Array = []) -> LevelProgression:
    return LevelProgression.new(chapters, completed)

func _chapter(cid: String, level_ids: Array) -> ChapterResource:
    var ch := ChapterResource.new()
    ch.id = cid
    ch.display_name = cid
    for lid in level_ids:
        var lr := LevelResource.new()
        lr.meta = LevelMeta.new()
        lr.meta.id = lid
        lr.meta.display_name = lid
        ch.main_levels.append(lr)
    return ch

func _entries(level_ids: Array) -> Array:
    var out: Array = []
    for i in range(level_ids.size()):
        var e := LevelMapEntry.new()
        e.level_id = level_ids[i]
        e.position = Vector2(i * 60, i * 60)
        out.append(e)
    return out

func test_chapter_path_builds_one_node_per_level():
    var view := ChapterPathView.new()
    add_child(view)
    var ch := _chapter("ch1", ["1-1", "1-2", "1-3"])
    view.build(_entries(["1-1", "1-2", "1-3"]), ch, _prog([ch]), Color.GREEN)
    var level_panels := view.get_children().filter(func(c): return c.is_in_group("level_node"))
    assert_eq(level_panels.size(), 3)

func test_chapter_path_emits_level_selected():
    var view := ChapterPathView.new()
    add_child(view)
    var ch := _chapter("ch1", ["1-1", "1-2"])
    view.build(_entries(["1-1", "1-2"]), ch, _prog([ch]), Color.GREEN)
    var captured: Array = []
    view.level_selected.connect(func(l): captured.append(l))
    view.select_level(0)
    assert_eq(captured.size(), 1)
    assert_eq((captured[0] as LevelResource).meta.id, "1-1")

func test_chapter_path_emits_back():
    var view := ChapterPathView.new()
    add_child(view)
    var ch := _chapter("ch1", ["1-1"])
    view.build(_entries(["1-1"]), ch, _prog([ch]), Color.GREEN)
    var emitted := [false]
    view.back_to_world.connect(func(): emitted[0] = true)
    view.request_back()
    assert_true(emitted[0])
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_level_menu`
Expected: FAIL(`ChapterPathView` 不存在)

- [ ] **Step 3: 写最小实现**

`scripts/ui/level_menu/chapter_path_view.gd`:
```gdscript
class_name ChapterPathView
extends Control

signal level_selected(level: LevelResource)
signal back_to_world()

var _back_button: Button
var _theme_color: Color = Color.GREEN
var _entries: Array = []
var _positions: Array[Vector2] = []

func build(entries: Array, chapter: ChapterResource, progression: LevelProgression, theme_color: Color) -> void:
    for c in get_children():
        c.queue_free()
    _entries = entries
    _theme_color = theme_color
    _positions.clear()
    var unlocked := progression.unlocked_ids()
    var highlighted := progression.highlighted_id()
    _back_button = Button.new()
    _back_button.text = "◀ 返回世界"
    _back_button.position = Vector2(10, 10)
    _back_button.pressed.connect(request_back)
    add_child(_back_button)
    for i in range(entries.size()):
        var entry: LevelMapEntry = entries[i] as LevelMapEntry
        var level: LevelResource = chapter.main_levels[i] as LevelResource
        var is_unlocked: bool = entry.level_id in unlocked
        var node := _make_node(entry, level, is_unlocked, entry.level_id == highlighted, progression.is_completed(entry.level_id), i)
        add_child(node)
        _positions.append(entry.position)
    queue_redraw()

func select_level(index: int) -> void:
    var entry: LevelMapEntry = _entries[index] as LevelMapEntry
    var panels := get_children().filter(func(c): return c.is_in_group("level_node"))
    var chapter_children: Array = get_tree() == null and [] or _chapter_levels()
    var level_res := _level_at(index)
    if level_res != null:
        level_selected.emit(level_res)

func request_back() -> void:
    back_to_world.emit()

func _chapter_levels() -> Array:
    return get_children().filter(func(c): return c.is_in_group("level_node"))

func _level_at(index: int) -> LevelResource:
    return _entries[index].get("level_res") if _entries[index].has_method("get") else null

func _make_node(entry: LevelMapEntry, level: LevelResource, unlocked: bool, highlighted: bool, completed: bool, index: int) -> Panel:
    var panel := Panel.new()
    panel.add_to_group("level_node")
    panel.position = entry.position
    panel.size = Vector2(48, 48)
    var lbl := Label.new()
    lbl.text = ("%d✓" % (index + 1)) if completed else ("%d" % (index + 1))
    if highlighted:
        lbl.text = "▶" + lbl.text
    if not unlocked:
        lbl.text = "🔒"
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.size = Vector2(48, 48)
    panel.add_child(lbl)
    panel.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.4)
    if unlocked:
        panel.gui_input.connect(func(ev: InputEvent) -> void:
            if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                _on_level_clicked(index))
    return panel

var _levels_ref: Array = []

func _on_level_clicked(index: int) -> void:
    level_selected.emit(_levels_ref[index])

func _draw() -> void:
    if _positions.size() < 2:
        return
    var col := _theme_color
    for i in range(_positions.size() - 1):
        draw_dashed_line(_positions[i] + Vector2(24, 24), _positions[i + 1] + Vector2(24, 24), col, 2.0, 6.0)
```

> 注:`select_level` / `_on_level_clicked` 需要把 `LevelResource` 与 index 对应起来。上面 `_levels_ref` 漏填,Step 3 正确实现如下(覆盖 `build` 末尾与 `select_level`):实际把 `chapter` 存为成员供查。**修正:把 `build` 签名里的 `chapter` 存成员 `_chapter`, `select_level`/`_on_level_clicked` 用 `_chapter.main_levels[index]`。** 见 Step 3b。

- [ ] **Step 3b: 修正实现(存 chapter 成员,补全关卡→LevelResource)**

替换 `chapter_path_view.gd` 全文为:
```gdscript
class_name ChapterPathView
extends Control

signal level_selected(level: LevelResource)
signal back_to_world()

var _back_button: Button
var _theme_color: Color = Color.GREEN
var _positions: Array[Vector2] = []
var _chapter: ChapterResource
var _entry_count: int = 0

func build(entries: Array, chapter: ChapterResource, progression: LevelProgression, theme_color: Color) -> void:
    for c in get_children():
        c.queue_free()
    _chapter = chapter
    _entry_count = entries.size()
    _theme_color = theme_color
    _positions.clear()
    var unlocked := progression.unlocked_ids()
    var highlighted := progression.highlighted_id()
    _back_button = Button.new()
    _back_button.text = "◀ 返回世界"
    _back_button.position = Vector2(10, 10)
    _back_button.pressed.connect(request_back)
    add_child(_back_button)
    for i in range(entries.size()):
        var entry: LevelMapEntry = entries[i] as LevelMapEntry
        var level: LevelResource = chapter.main_levels[i] as LevelResource
        var is_unlocked: bool = entry.level_id in unlocked
        add_child(_make_node(entry, level, is_unlocked, entry.level_id == highlighted, progression.is_completed(entry.level_id), i))
        _positions.append(entry.position)
    queue_redraw()

func select_level(index: int) -> void:
    if _chapter == null or index >= _chapter.main_levels.size():
        return
    level_selected.emit(_chapter.main_levels[index] as LevelResource)

func request_back() -> void:
    back_to_world.emit()

func _make_node(entry: LevelMapEntry, level: LevelResource, unlocked: bool, highlighted: bool, completed: bool, index: int) -> Panel:
    var panel := Panel.new()
    panel.add_to_group("level_node")
    panel.position = entry.position
    panel.size = Vector2(48, 48)
    var lbl := Label.new()
    var txt: String = ("%d✓" % (index + 1)) if completed else ("%d" % (index + 1))
    if highlighted:
        txt = "▶" + txt
    if not unlocked:
        txt = "🔒"
    lbl.text = txt
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_VERTICAL_CENTER if false else HORIZONTAL_ALIGNMENT_CENTER
    lbl.size = Vector2(48, 48)
    panel.add_child(lbl)
    panel.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.4)
    if unlocked:
        var idx := index
        panel.gui_input.connect(func(ev: InputEvent) -> void:
            if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                select_level(idx))
    return panel

func _draw() -> void:
    if _positions.size() < 2:
        return
    for i in range(_positions.size() - 1):
        draw_dashed_line(_positions[i] + Vector2(24, 24), _positions[i + 1] + Vector2(24, 24), _theme_color, 2.0, 6.0)
```

> 上面 `lbl.vertical_alignment` 一行是为规避 `HORIZONTAL_ALIGNMENT_CENTER` 复用的笔误;Label 垂直对齐用 `VERTICAL_ALIGNMENT_CENTER`。实现期用 `lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER`,**不要**照抄含 `if false` 的行。最终实现:
```gdscript
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS(3 test)。`draw_dashed_line` 在无渲染的 headless `_draw` 不会触发(未入树或 queue_redraw 未执行),不会报错。

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/level_menu/chapter_path_view.gd tests/ui/test_level_menu.gd
git commit -m "$(cat <<'EOF'
feat(level-menu): ChapterPathView 第二级关卡路径视图(节点数+信号测试)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: WorldMapView(第一级岛屿视图)

**Files:**
- Create: `scripts/ui/level_menu/world_map_view.gd`
- Test: `tests/ui/test_level_menu.gd`(追加)

- [ ] **Step 1: 写失败测试(岛屿节点数 + 信号)**

追加到 `tests/ui/test_level_menu.gd`:
```gdscript
func _layout(chapters: Array) -> WorldMapLayout:
    var layout := WorldMapLayout.new()
    layout.canvas_size = Vector2(400, 800)
    var entries: Array = []
    var i := 0
    for ch in chapters:
        var ce := ChapterMapEntry.new()
        ce.chapter_id = (ch as ChapterResource).id
        ce.position = Vector2(200, 150 + i * 250)
        ce.theme_color = Color.GREEN
        ce.icon = "🏯"
        ce.path_size = Vector2(400, 600)
        for lvl in (ch as ChapterResource).main_levels:
            var le := LevelMapEntry.new()
            le.level_id = (lvl as LevelResource).meta.id
            le.position = Vector2(50, 50)
            ce.levels.append(le)
        entries.append(ce)
        i += 1
    layout.chapters = entries
    return layout

func test_world_map_builds_one_island_per_chapter():
    var view := WorldMapView.new()
    add_child(view)
    var ch1 := _chapter("ch1", ["1-1"])
    var ch2 := _chapter("ch2", ["2-1"])
    var layout := _layout([ch1, ch2])
    view.build(layout, [ch1, ch2], _prog([ch1, ch2]))
    var islands := view.get_children().filter(func(c): return c.is_in_group("island_node"))
    assert_eq(islands.size(), 2)

func test_world_map_emits_chapter_selected():
    var view := WorldMapView.new()
    add_child(view)
    var ch1 := _chapter("ch1", ["1-1"])
    var ch2 := _chapter("ch2", ["2-1"])
    var layout := _layout([ch1, ch2])
    view.build(layout, [ch1, ch2], _prog([ch1, ch2]))
    var captured_id := [""]
    view.chapter_selected.connect(func(cid, anchor): captured_id[0] = cid)
    view.select_island(1)
    assert_eq(captured_id[0], "ch2")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_level_menu`
Expected: FAIL(`WorldMapView` 不存在)

- [ ] **Step 3: 写最小实现**

`scripts/ui/level_menu/world_map_view.gd`:
```gdscript
class_name WorldMapView
extends Control

signal chapter_selected(chapter_id: String, anchor: Vector2)

var _scroll: ScrollContainer
var _content: Control
var _entries: Array = []
var _chapters: Array = []

func build(layout: WorldMapLayout, chapters: Array, progression: LevelProgression) -> void:
    for c in get_children():
        c.queue_free()
    _entries = layout.chapters
    _chapters = chapters
    _scroll = ScrollContainer.new()
    _scroll.size = size if size != Vector2.ZERO else Vector2(720, 720)
    _scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_scroll)
    _content = Control.new()
    _content.size = layout.canvas_size
    _scroll.add_child(_content)
    var unlocked := progression.unlocked_ids()
    var highlighted := progression.highlighted_id()
    for i in range(layout.chapters.size()):
        var entry: ChapterMapEntry = layout.chapters[i] as ChapterMapEntry
        var ch: ChapterResource = _find_chapter(entry.chapter_id)
        var first_unlocked: bool = ch != null and ch.main_levels.size() > 0 and (ch.main_levels[0] as LevelResource).meta.id in unlocked
        var ch_highlighted: bool = ch != null and highlighted != "" and _chapter_has(ch, highlighted)
        _content.add_child(_make_island(entry, ch, first_unlocked, ch_highlighted, i))
    if not _scroll.scroll_changed.is_connected(_on_scroll_changed):
        _scroll.scroll_changed.connect(_on_scroll_changed)
    queue_redraw()

func select_island(index: int) -> void:
    if index < 0 or index >= _entries.size():
        return
    var entry: ChapterMapEntry = _entries[index] as ChapterMapEntry
    chapter_selected.emit(entry.chapter_id, entry.position)

func _find_chapter(cid: String) -> ChapterResource:
    for ch in _chapters:
        if (ch as ChapterResource).id == cid:
            return ch
    return null

func _chapter_has(ch: ChapterResource, level_id: String) -> bool:
    for lvl in ch.main_levels:
        if (lvl as LevelResource).meta.id == level_id:
            return true
    return false

func _make_island(entry: ChapterMapEntry, ch: ChapterResource, unlocked: bool, highlighted: bool, index: int) -> Control:
    var island := Panel.new()
    island.add_to_group("island_node")
    island.position = entry.position - Vector2(60, 40)
    island.size = Vector2(120, 80)
    var name := Label.new()
    name.text = entry.icon + " " + (ch.display_name if ch != null else entry.chapter_id)
    name.position = Vector2(6, 6)
    island.add_child(name)
    if not unlocked:
        var lock := Label.new()
        lock.text = "🔒"
        lock.position = Vector2(45, 40)
        island.add_child(lock)
    island.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.4)
    if highlighted:
        island.modulate = Color(1.15, 1.15, 1.15)
    if unlocked:
        var cid: String = entry.chapter_id
        var anchor: Vector2 = entry.position
        island.gui_input.connect(func(ev: InputEvent) -> void:
            if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
                chapter_selected.emit(cid, anchor))
    return island

func _on_scroll_changed() -> void:
    queue_redraw()

func _draw() -> void:
    if _entries.size() < 2 or _scroll == null:
        return
    var offset := Vector2(-_scroll.scroll_horizontal, -_scroll.scroll_vertical)
    for i in range(_entries.size() - 1):
        var a: Vector2 = (_entries[i] as ChapterMapEntry).position + offset
        var b: Vector2 = (_entries[i + 1] as ChapterMapEntry).position + offset
        draw_dashed_line(a, b, Color(0.5, 0.45, 0.3), 2.0, 8.0)
```

> `_content.draw.connect(_draw_connections)` 依赖 Control 的 `draw` 信号;若 headless 下未入树 `_content.queue_redraw()` 无效,但不影响断言(只验节点数与信号)。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS(5 test)

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/level_menu/world_map_view.gd tests/ui/test_level_menu.gd
git commit -m "$(cat <<'EOF'
feat(level-menu): WorldMapView 第一级岛屿视图(节点数+信号测试)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: LevelMenu(协调 + 伪 Zoom + 状态机)+ level_menu.tscn

**Files:**
- Create: `scripts/ui/level_menu/level_menu.gd`
- Create: `Scenes/level_menu.tscn`
- Test: `tests/ui/test_level_menu.gd`(追加)

- [ ] **Step 1: 写失败测试(状态机 + level_chosen)**

追加到 `tests/ui/test_level_menu.gd`:
```gdscript
func test_menu_setup_builds_world():
    var menu := LevelMenu.new()
    add_child(menu)
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var layout := _layout([ch1])
    menu.setup([ch1], layout, _prog([ch1]))
    assert_eq(menu.current_state(), LevelMenu.STATE_WORLD)

func test_menu_enter_chapter_then_choose_level():
    var menu := LevelMenu.new()
    add_child(menu)
    var ch1 := _chapter("ch1", ["1-1", "1-2"])
    var layout := _layout([ch1])
    menu.setup([ch1], layout, _prog([ch1]))
    menu.enter_chapter("ch1", Vector2(200, 150))
    assert_eq(menu.current_state(), LevelMenu.STATE_CHAPTER)
    var captured: Array = []
    menu.level_chosen.connect(func(l): captured.append(l))
    menu.choose_level("1-1")
    assert_eq(captured.size(), 1)

func test_menu_back_to_world():
    var menu := LevelMenu.new()
    add_child(menu)
    var ch1 := _chapter("ch1", ["1-1"])
    var layout := _layout([ch1])
    menu.setup([ch1], layout, _prog([ch1]))
    menu.enter_chapter("ch1", Vector2(200, 150))
    menu.back_to_world_requested()
    assert_eq(menu.current_state(), LevelMenu.STATE_WORLD)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit -gselect=test_level_menu`
Expected: FAIL(`LevelMenu` 不存在)

- [ ] **Step 3: 写最小实现**

`scripts/ui/level_menu/level_menu.gd`:
```gdscript
class_name LevelMenu
extends Control

enum State { WORLD, CHAPTER }

const TRANS_TIME := 0.4

signal level_chosen(level: LevelResource)

var _chapters: Array = []
var _layout: WorldMapLayout
var _progression: LevelProgression
var _state: int = State.WORLD
var _current_chapter_id: String = ""
@onready var _world_view: WorldMapView = $WorldMapView
@onready var _path_view: ChapterPathView = $ChapterPathView

func setup(chapters: Array, layout: WorldMapLayout, progression: LevelProgression) -> void:
    _chapters = chapters
    _layout = layout
    _progression = progression
    _state = State.WORLD
    _world_view.build(layout, chapters, progression)
    _path_view.visible = false

func current_state() -> int:
    return _state

func enter_chapter(chapter_id: String, anchor: Vector2) -> void:
    _current_chapter_id = chapter_id
    _state = State.CHAPTER
    var entry := _find_entry(chapter_id)
    var ch := _find_chapter(chapter_id)
    if entry == null or ch == null:
        return
    _path_view.build(entry.levels, ch, _progression, entry.theme_color)
    _play_enter_tween(anchor)

func choose_level(level_id: String) -> void:
    var ch := _find_chapter(_current_chapter_id)
    if ch == null:
        return
    for lvl in ch.main_levels:
        if (lvl as LevelResource).meta.id == level_id:
            level_chosen.emit(lvl as LevelResource)
            return

func back_to_world_requested() -> void:
    _state = State.WORLD
    _play_exit_tween()

func refresh() -> void:
    if _state != State.CHAPTER:
        return
    var entry := _find_entry(_current_chapter_id)
    var ch := _find_chapter(_current_chapter_id)
    if entry != null and ch != null:
        _path_view.build(entry.levels, ch, _progression, entry.theme_color)

func _find_entry(cid: String) -> ChapterMapEntry:
    for e in _layout.chapters:
        if (e as ChapterMapEntry).chapter_id == cid:
            return e
    return null

func _find_chapter(cid: String) -> ChapterResource:
    for ch in _chapters:
        if (ch as ChapterResource).id == cid:
            return ch
    return null

func _play_enter_tween(anchor: Vector2) -> void:
    _path_view.visible = true
    _path_view.modulate.a = 0.0
    _path_view.scale = Vector2(0.3, 0.3)
    var tw := create_tween().set_parallel(true)
    tw.tween_property(_world_view, "modulate:a", 0.35, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "modulate:a", 1.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "scale", Vector2.ONE, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_exit_tween() -> void:
    var tw := create_tween().set_parallel(true)
    tw.tween_property(_world_view, "modulate:a", 1.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "modulate:a", 0.0, TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(_path_view, "scale", Vector2(0.3, 0.3), TRANS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.chain().tween_callback(func(): _path_view.visible = false)
```

- [ ] **Step 4: 建场景 `Scenes/level_menu.tscn`**

手动创建(Godot 编辑器)或用如下文本(存为 `Scenes/level_menu.tscn`):
```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/level_menu/level_menu.gd" id="1_menu"]
[ext_resource type="Script" path="res://scripts/ui/level_menu/world_map_view.gd" id="2_wmv"]
[ext_resource type="Script" path="res://scripts/ui/level_menu/chapter_path_view.gd" id="3_cpv"]

[node name="LevelMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_menu")

[node name="WorldMapView" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("2_wmv")

[node name="ChapterPathView" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
visible = false
script = ExtResource("3_cpv")
```

Run: `"$GODOT" --headless --path . --import`(生成 uid)

- [ ] **Step 5: 连接内部信号(LevelMenu → 子 view)**

`LevelMenu` 用 `@onready` 拿子节点,但子 view 的信号需在运行时连。在 `setup()` 末尾追加连接:
```gdscript
    if not _world_view.chapter_selected.is_connected(_on_chapter_selected):
        _world_view.chapter_selected.connect(_on_chapter_selected)
    if not _path_view.level_selected.is_connected(_on_level_selected):
        _path_view.level_selected.connect(_on_level_selected)
    if not _path_view.back_to_world.is_connected(_on_back_to_world):
        _path_view.back_to_world.connect(_on_back_to_world)
```
并在类体内加:
```gdscript
func _on_chapter_selected(chapter_id: String, anchor: Vector2) -> void:
    enter_chapter(chapter_id, anchor)

func _on_level_selected(level: LevelResource) -> void:
    level_chosen.emit(level)

func _on_back_to_world() -> void:
    back_to_world_requested()
```

> 测试里直接调 `menu.enter_chapter` / `menu.choose_level` / `menu.back_to_world_requested`,不依赖子 view 信号链(那是人工 QA 覆盖)。但 `_on_level_selected` 转发与 `choose_level` 重复——`choose_level` 供测试,`_on_level_selected` 供运行时第二级点击;二者并存。

- [ ] **Step 6: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS(8 test)

- [ ] **Step 7: 提交**

```bash
git add scripts/ui/level_menu/level_menu.gd Scenes/level_menu.tscn tests/ui/test_level_menu.gd
git commit -m "$(cat <<'EOF'
feat(level-menu): LevelMenu 两级协调+伪Zoom+状态机 + level_menu.tscn

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: boot.gd 改造(接入 LevelMenu)

**Files:**
- Modify: `scripts/ui/boot.gd`
- Modify: `tests/ui/test_boot.gd`

- [ ] **Step 1: 改写 `test_boot.gd`(适配 + layout 缺失降级)**

`tests/ui/test_boot.gd` 全文:
```gdscript
extends GutTest

func test_ready_safe_without_chapter_files():
    var boot := Boot.new()
    boot.chapter_paths = ["res://resources/chapters/__nonexistent__.tres"]
    boot.layout_path = "res://resources/menu/__nonexistent__.tres"
    add_child(boot)
    assert_not_null(boot._progression)
    assert_eq(boot._chapters, [])

func test_level_instance_cleaned_on_exit():
    var boot := Boot.new()
    add_child(boot)
    boot._exit_level()
    assert_true(boot._level_instance == null)
```

- [ ] **Step 2: 改写 `scripts/ui/boot.gd` 全文**

```gdscript
class_name Boot
extends Control

const LevelScene := preload("res://Scenes/level.tscn")
const LevelMenuScene := preload("res://Scenes/level_menu.tscn")

@export var chapter_paths: Array[String] = [
    "res://resources/chapters/chapter_01.tres",
    "res://resources/chapters/chapter_02.tres",
]
@export var layout_path: String = "res://resources/menu/world_map_layout.tres"

var _chapters: Array[ChapterResource] = []
var _progression: LevelProgression
var _level_menu: LevelMenu
var _level_instance: Node

func _ready() -> void:
    _load_chapters()
    _progression = LevelProgression.new(_chapters)
    _build_menu()

func _load_chapters() -> void:
    _chapters = []
    for path in chapter_paths:
        if ResourceLoader.exists(path):
            var ch := load(path) as ChapterResource
            if ch != null:
                _chapters.append(ch)

func _build_menu() -> void:
    var layout: WorldMapLayout = null
    if ResourceLoader.exists(layout_path):
        layout = load(layout_path) as WorldMapLayout
    if layout == null:
        return
    _level_menu = LevelMenuScene.instantiate()
    add_child(_level_menu)
    _level_menu.setup(_chapters, layout, _progression)
    _level_menu.level_chosen.connect(_on_level_chosen)

func _on_level_chosen(level: LevelResource) -> void:
    if _level_menu != null:
        _level_menu.visible = false
    _level_instance = LevelScene.instantiate()
    _level_instance.level = level
    _level_instance.won.connect(_on_level_won)
    _level_instance.back_requested.connect(_on_level_back)
    add_child(_level_instance)

func _on_level_won() -> void:
    var id: String = (_level_instance.level as LevelResource).meta.id
    _progression.mark_completed(id)
    _exit_level()
    if _level_menu != null:
        _level_menu.visible = true
        _level_menu.refresh()

func _on_level_back() -> void:
    _exit_level()
    if _level_menu != null:
        _level_menu.visible = true

func _exit_level() -> void:
    if _level_instance != null:
        _level_instance.queue_free()
        _level_instance = null
```

- [ ] **Step 3: 跑 boot + 全部测试确认通过**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全 PASS(128 + 本特性新增 = 总数,无退化)。`test_ready_safe` 在 layout 缺失时 `_build_menu` 直接 return(不实例化 LevelMenu),`_progression`/`_chapters` 满足断言。

- [ ] **Step 4: 提交**

```bash
git add scripts/ui/boot.gd tests/ui/test_boot.gd
git commit -m "$(cat <<'EOF'
refactor(level-menu): boot.gd 接入 LevelMenu(去 VBox,保留测试依赖字段)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: 集成验证 + 人工 QA + 主场景修正

**Files:** 无新代码(验证 + 文档)

- [ ] **Step 1: 全量 GUT 回归**

Run: `"$GODOT" --headless --path . --import && "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: 全绿,无兼容警告,新增测试包含:`test_world_map_layout`、`test_world_map_layout_generated`、`test_level_menu`、`test_boot`(2)。

- [ ] **Step 2: 修正主场景(独立提交,见 spec 审查发现)**

`project.godot` 的 `run/main_scene` 由 `res://Scenes/level.tscn` 改为 boot.tscn 的 uid。编辑 `project.godot`:
```
run/main_scene="res://Scenes/boot.tscn"
```
(用路径形式,Godot 运行时自解析;或编辑器内 项目设置→主场景 选 boot.tscn。)

Run: 启动游戏确认进 boot 选关入口。
```bash
git add project.godot
git commit -m "$(cat <<'EOF'
fix(boot): 主场景由 level.tscn 改为 boot.tscn(选关入口为启动入口)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: 人工 QA(用户执行,对照 spec §10 验收)**

启动游戏,逐项确认:
- [ ] 启动即第一级世界岛屿地图(2 岛屿),前院可进入高亮、后山锁定,竖向可滚动
- [ ] 点前院 → 伪 Zoom 过渡 → 第二级前院路径(5 节点),1-1 解锁高亮、1-2~1-5 锁定
- [ ] 点 1-1 → 进入关卡;通关 → 回第二级,1-1 ✓、1-2 解锁高亮
- [ ] 关卡内返回 → 回当前章节第二级(不解锁)
- [ ] 第二级返回按钮 → 反向 Tween → 回第一级
- [ ] 占位美术(emoji/色块)章节与状态可辨识

- [ ] **Step 4: 更新 memory(由实施者或用户)**

记录:两级地图菜单已实现(分支/commit)、新增测试数、QA 结论。若趣味/美术待优化,记入「下一步」。

---

## Self-Review(plan 写完后自检,已执行)

1. **Spec 覆盖**:D1 岛屿(Task 5)、D2 路径(Task 4)、D3 伪Zoom(Task 6)、D4 独立 Resource(Task 1)、D5 线性连线(Task 4/5 `_draw`)、D6 模块化(Task 4-7)、D7 复用 progression(Task 4-7)、D8 手工.tres(Task 3)、D9 占位美术(Task 4/5)——全覆盖。§9 测试→Task 1/2/3/4/5/6/7;§10 验收→Task 8。
2. **占位符**:Task 4 Step 3 残留草稿已被 Step 3b 修正覆盖,最终实现以 Step 3b 为准(且明确提示 `lbl.vertical_alignment` 用 `VERTICAL_ALIGNMENT_CENTER`)。
3. **类型一致**:`select_level`/`select_island`/`choose_level`/`enter_chapter`/`back_to_world_requested`/`refresh`/`setup`/`current_state`/`validate` 在各 Task 与测试中签名一致;`STATE_WORLD`/`STATE_CHAPTER` 与 `State` 枚举一致。
